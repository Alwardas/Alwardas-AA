use axum::{
    extract::{State, Query, Path},
    Json,
    http::StatusCode,
};
use serde_json::json;
use crate::models::{AppState, chat::*};

// 1. Search User by Exact ERP ID
pub async fn search_user_handler(
    State(state): State<AppState>,
    Query(params): Query<ChatSearchQuery>,
    Query(current_user): Query<serde_json::Value>, // expect current_user_id as query param
) -> Result<Json<ChatUserSearchResult>, (StatusCode, Json<serde_json::Value>)> {
    let erp_id = params.erp_id.trim();
    let current_id = current_user.get("user_id").and_then(|v| v.as_str()).unwrap_or("");

    // Look up in users table
    let user_opt = sqlx::query!(
        "SELECT full_name, role, login_id, branch, section FROM users WHERE login_id = $1",
        erp_id
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
        )
    })?;

    let user = match user_opt {
        Some(u) => u,
        None => {
            return Err((
                StatusCode::NOT_FOUND,
                Json(json!({ "success": false, "message": "No user found with the exact ERP ID" })),
            ));
        }
    };

    // Check request status
    let req_opt = sqlx::query!(
        "SELECT status, sender_id, receiver_id FROM chat_requests 
         WHERE (sender_id = $1 AND receiver_id = $2) OR (sender_id = $2 AND receiver_id = $1)",
        current_id,
        erp_id
    )
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let is_connected = req_opt.as_ref().map_or(false, |r| r.status == "ACCEPTED");
    let connection_status = req_opt.map(|r| r.status);

    Ok(Json(ChatUserSearchResult {
        full_name: user.full_name,
        role: user.role,
        login_id: user.login_id,
        branch: user.branch,
        section: user.section,
        is_connected,
        connection_status,
    }))
}

// 2. Send Chat Request
pub async fn send_request_handler(
    State(state): State<AppState>,
    Json(payload): Json<ChatRequestPayload>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    // Check if blocked
    let is_blocked = sqlx::query_scalar!(
        "SELECT EXISTS(SELECT 1 FROM chat_blocks WHERE (blocker_id = $1 AND blocked_id = $2) OR (blocker_id = $2 AND blocked_id = $1))",
        payload.sender_id,
        payload.receiver_id
    )
    .fetch_one(&state.pool)
    .await
    .unwrap_or(Some(false))
    .unwrap_or(false);

    if is_blocked {
        return Err((
            StatusCode::FORBIDDEN,
            Json(json!({ "success": false, "message": "Cannot send request. User has blocked you or is blocked." })),
        ));
    }

    sqlx::query!(
        "INSERT INTO chat_requests (sender_id, receiver_id, optional_message, status)
         VALUES ($1, $2, $3, 'PENDING')
         ON CONFLICT (sender_id, receiver_id) DO UPDATE 
         SET status = 'PENDING', optional_message = $3, updated_at = NOW()",
        payload.sender_id,
        payload.receiver_id,
        payload.optional_message
    )
    .execute(&state.pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
        )
    })?;

    Ok(StatusCode::OK)
}

// 3. Get Pending/All Chat Requests
pub async fn get_requests_handler(
    State(state): State<AppState>,
    Query(params): Query<serde_json::Value>,
) -> Result<Json<Vec<ChatRequestResponse>>, (StatusCode, Json<serde_json::Value>)> {
    let user_id = params.get("user_id").and_then(|v| v.as_str()).ok_or((
        StatusCode::BAD_REQUEST,
        Json(json!({ "success": false, "message": "Missing user_id query parameter" })),
    ))?;

    let requests = sqlx::query_as!(
        ChatRequestResponse,
        r#"SELECT r.id, r.sender_id, u_send.full_name as sender_name, u_send.role as sender_role, u_send.branch as sender_branch,
                  r.receiver_id, u_recv.full_name as receiver_name, u_recv.role as receiver_role, u_recv.branch as receiver_branch,
                  r.optional_message, r.status, r.created_at as "created_at!"
           FROM chat_requests r
           JOIN users u_send ON r.sender_id = u_send.login_id
           JOIN users u_recv ON r.receiver_id = u_recv.login_id
           WHERE r.sender_id = $1 OR r.receiver_id = $1"#,
        user_id
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
        )
    })?;

    Ok(Json(requests))
}

// 4. Respond to Chat Request (ACCEPT or REJECT)
pub async fn respond_request_handler(
    State(state): State<AppState>,
    Path(id): Path<uuid::Uuid>,
    Json(payload): Json<RespondRequestPayload>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let status = payload.action.to_uppercase();
    if status == "REJECTED" || status == "REJECT" {
        sqlx::query!("DELETE FROM chat_requests WHERE id = $1", id)
            .execute(&state.pool)
            .await
            .map_err(|e| {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
                )
            })?;
    } else {
        sqlx::query!(
            "UPDATE chat_requests SET status = $1, updated_at = NOW() WHERE id = $2",
            status,
            id
        )
        .execute(&state.pool)
        .await
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
            )
        })?;
    }

    Ok(StatusCode::OK)
}

// 5. Get Conversations List (direct connected contacts + groups)
pub async fn get_conversations_handler(
    State(state): State<AppState>,
    Query(params): Query<serde_json::Value>,
) -> Result<Json<Vec<ConversationResponse>>, (StatusCode, Json<serde_json::Value>)> {
    let user_id = params.get("user_id").and_then(|v| v.as_str()).ok_or((
        StatusCode::BAD_REQUEST,
        Json(json!({ "success": false, "message": "Missing user_id query parameter" })),
    ))?;

    // Fetch direct messages (DMs) contacts
    let dms = sqlx::query!(
        r#"SELECT u.login_id as partner_id, u.full_name as partner_name, u.role as partner_role, u.branch as partner_branch, u.section as partner_section,
                  (SELECT content FROM chat_messages 
                   WHERE (sender_id = $1 AND receiver_id = u.login_id) OR (sender_id = u.login_id AND receiver_id = $1)
                   ORDER BY created_at DESC LIMIT 1) as last_message,
                  (SELECT created_at FROM chat_messages 
                   WHERE (sender_id = $1 AND receiver_id = u.login_id) OR (sender_id = u.login_id AND receiver_id = $1)
                   ORDER BY created_at DESC LIMIT 1) as last_message_time
           FROM chat_requests r
           JOIN users u ON (r.sender_id = u.login_id AND r.receiver_id = $1) OR (r.receiver_id = u.login_id AND r.sender_id = $1)
           WHERE r.status = 'ACCEPTED' AND u.login_id != $1"#,
        user_id
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    // Fetch groups
    let groups = sqlx::query!(
        r#"SELECT g.id, g.name, g.description, g.icon_url,
                  (SELECT content FROM chat_messages WHERE receiver_id = g.id ORDER BY created_at DESC LIMIT 1) as last_message,
                  (SELECT created_at FROM chat_messages WHERE receiver_id = g.id ORDER BY created_at DESC LIMIT 1) as last_message_time
           FROM chat_groups g
           JOIN chat_group_members gm ON g.id = gm.group_id
           WHERE gm.user_id = $1"#,
        user_id
    )
    .fetch_all(&state.pool)
    .await
    .unwrap_or_default();

    let mut conversations = Vec::new();

    for dm in dms {
        conversations.push(ConversationResponse {
            id: dm.partner_id.clone(),
            name: dm.partner_name,
            role: Some(dm.partner_role),
            branch: dm.partner_branch,
            section: dm.partner_section,
            is_group: false,
            last_message: dm.last_message,
            last_message_time: dm.last_message_time,
            unread_count: 0,
            description: None,
            icon_url: None,
        });
    }

    for g in groups {
        conversations.push(ConversationResponse {
            id: g.id,
            name: g.name,
            role: None,
            branch: None,
            section: None,
            is_group: true,
            last_message: g.last_message,
            last_message_time: g.last_message_time,
            unread_count: 0,
            description: g.description,
            icon_url: g.icon_url,
        });
    }

    // Sort by last message time, descending
    conversations.sort_by(|a, b| {
        b.last_message_time.unwrap_or_else(|| chrono::DateTime::from_timestamp(0, 0).unwrap().with_timezone(&chrono::Utc))
            .cmp(&a.last_message_time.unwrap_or_else(|| chrono::DateTime::from_timestamp(0, 0).unwrap().with_timezone(&chrono::Utc)))
    });

    Ok(Json(conversations))
}

// 6. Get Message History for a conversation (direct partner or group)
pub async fn get_messages_handler(
    State(state): State<AppState>,
    Path(partner_id): Path<String>,
    Query(params): Query<serde_json::Value>,
) -> Result<Json<Vec<ChatMessageResponse>>, (StatusCode, Json<serde_json::Value>)> {
    let user_id = params.get("user_id").and_then(|v| v.as_str()).ok_or((
        StatusCode::BAD_REQUEST,
        Json(json!({ "success": false, "message": "Missing user_id query parameter" })),
    ))?;

    let messages = if partner_id.starts_with("group_") {
        sqlx::query_as!(
            ChatMessageResponse,
            r#"SELECT m.id, m.sender_id, u.full_name as sender_name, m.receiver_id, m.content, m.message_type,
                      m.attachment_url, m.attachment_name, m.attachment_size, m.reply_to_id, m.reply_to_content,
                      m.is_starred, m.is_deleted_for_everyone, m.created_at as "created_at!"
               FROM chat_messages m
               JOIN users u ON m.sender_id = u.login_id
               WHERE m.receiver_id = $1
               ORDER BY m.created_at ASC"#,
            partner_id
        )
        .fetch_all(&state.pool)
        .await
    } else {
        sqlx::query_as!(
            ChatMessageResponse,
            r#"SELECT m.id, m.sender_id, u.full_name as sender_name, m.receiver_id, m.content, m.message_type,
                      m.attachment_url, m.attachment_name, m.attachment_size, m.reply_to_id, m.reply_to_content,
                      m.is_starred, m.is_deleted_for_everyone, m.created_at as "created_at!"
               FROM chat_messages m
               JOIN users u ON m.sender_id = u.login_id
               WHERE (m.sender_id = $1 AND m.receiver_id = $2) OR (m.sender_id = $2 AND m.receiver_id = $1)
               ORDER BY m.created_at ASC"#,
            user_id,
            partner_id
        )
        .fetch_all(&state.pool)
        .await
    }
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
        )
    })?;

    Ok(Json(messages))
}

// 7. Send Message
pub async fn send_message_handler(
    State(state): State<AppState>,
    Json(payload): Json<SendMessagePayload>,
) -> Result<Json<ChatMessageResponse>, (StatusCode, Json<serde_json::Value>)> {
    let msg = sqlx::query_as!(
        ChatMessageResponse,
        r#"INSERT INTO chat_messages (sender_id, receiver_id, content, message_type, attachment_url, attachment_name, attachment_size, reply_to_id, reply_to_content)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           RETURNING id, sender_id, receiver_id, content, message_type, attachment_url, attachment_name, attachment_size, reply_to_id, reply_to_content, is_starred, is_deleted_for_everyone, created_at as "created_at!",
                     (SELECT full_name FROM users WHERE login_id = $1) as sender_name"#,
        payload.sender_id,
        payload.receiver_id,
        payload.content,
        payload.message_type,
        payload.attachment_url,
        payload.attachment_name,
        payload.attachment_size,
        payload.reply_to_id,
        payload.reply_to_content
    )
    .fetch_one(&state.pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
        )
    })?;

    Ok(Json(msg))
}

// 8. Create Group
pub async fn create_group_handler(
    State(state): State<AppState>,
    Json(payload): Json<CreateGroupPayload>,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let group_uuid = uuid::Uuid::new_v4().to_string();
    let group_id = format!("group_{}", group_uuid);

    let mut tx = state.pool.begin().await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Transaction error: {:?}", e) })),
        )
    })?;

    // Create Group
    sqlx::query!(
        "INSERT INTO chat_groups (id, name, description, icon_url, created_by)
         VALUES ($1, $2, $3, $4, $5)",
        group_id,
        payload.name,
        payload.description,
        payload.icon_url,
        payload.creator_id
    )
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Database error inserting group: {:?}", e) })),
        )
    })?;

    // Add Creator as Admin
    sqlx::query!(
        "INSERT INTO chat_group_members (group_id, user_id, role)
         VALUES ($1, $2, 'ADMIN')",
        group_id,
        payload.creator_id
    )
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Database error inserting creator member: {:?}", e) })),
        )
    })?;

    // Add other members
    for member_id in payload.members {
        if member_id != payload.creator_id {
            sqlx::query!(
                "INSERT INTO chat_group_members (group_id, user_id, role)
                 VALUES ($1, $2, 'MEMBER')",
                group_id,
                member_id
            )
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    Json(json!({ "success": false, "message": format!("Database error inserting member: {:?}", e) })),
                )
            })?;
        }
    }

    tx.commit().await.map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Transaction commit error: {:?}", e) })),
        )
    })?;

    Ok(Json(json!({
        "success": true,
        "message": "Group created successfully",
        "data": {
            "id": group_id,
            "name": payload.name,
            "description": payload.description,
            "iconUrl": payload.icon_url,
        }
    })))
}

// 9. Block User Action
pub async fn block_user_handler(
    State(state): State<AppState>,
    Json(payload): Json<ChatBlockPayload>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let action = payload.action.to_uppercase();

    if action == "BLOCK" {
        sqlx::query!(
            "INSERT INTO chat_blocks (blocker_id, blocked_id) VALUES ($1, $2) ON CONFLICT DO NOTHING",
            payload.user_id,
            payload.blocked_id
        )
        .execute(&state.pool)
        .await
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
            )
        })?;

        // Delete any pending requests
        sqlx::query!(
            "DELETE FROM chat_requests WHERE (sender_id = $1 AND receiver_id = $2) OR (sender_id = $2 AND receiver_id = $1)",
            payload.user_id,
            payload.blocked_id
        )
        .execute(&state.pool)
        .await
        .ok();
    } else {
        sqlx::query!(
            "DELETE FROM chat_blocks WHERE blocker_id = $1 AND blocked_id = $2",
            payload.user_id,
            payload.blocked_id
        )
        .execute(&state.pool)
        .await
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
            )
        })?;
    }

    Ok(StatusCode::OK)
}

// 10. Get Blocked Users
pub async fn get_blocked_users_handler(
    State(state): State<AppState>,
    Query(params): Query<serde_json::Value>,
) -> Result<Json<Vec<String>>, (StatusCode, Json<serde_json::Value>)> {
    let user_id = params.get("user_id").and_then(|v| v.as_str()).ok_or((
        StatusCode::BAD_REQUEST,
        Json(json!({ "success": false, "message": "Missing user_id query parameter" })),
    ))?;

    let blocked = sqlx::query_scalar!(
        "SELECT blocked_id FROM chat_blocks WHERE blocker_id = $1",
        user_id
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
        )
    })?;

    Ok(Json(blocked))
}

// 11. Delete Message
pub async fn delete_message_handler(
    State(state): State<AppState>,
    Path(id): Path<uuid::Uuid>,
    Query(params): Query<serde_json::Value>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let for_everyone = params.get("for_everyone").and_then(|v| v.as_bool()).unwrap_or(false);

    if for_everyone {
        sqlx::query!(
            "UPDATE chat_messages SET is_deleted_for_everyone = true WHERE id = $1",
            id
        )
        .execute(&state.pool)
        .await
        .map_err(|e| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
            )
        })?;
    } else {
        sqlx::query!("DELETE FROM chat_messages WHERE id = $1", id)
            .execute(&state.pool)
            .await
            .map_err(|e| {
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    Json(json!({ "success": false, "message": format!("Database error: {:?}", e) })),
                )
            })?;
    }

    Ok(StatusCode::OK)
}
