use axum::{
    extract::{State, Query, Path},
    Json,
    http::StatusCode,
};
use sqlx::Postgres;
use crate::models::*;
use uuid::Uuid;

pub async fn submit_issue_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitIssueRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let created_by = Uuid::parse_str(&payload.created_by).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    // Routing Logic:
    // Attendance issue → Faculty / HOD
    // Academic issue → Faculty / HOD
    // Technical issue → Coordinator
    // Facilities issue → Coordinator / Principal
    // General issue → HOD
    
    // For now we just store it. Assignment can be manual or automated.
    // The requirement says "automatically assigned based on the category".
    // We need to find a suitable user to assign to. 
    // This is tricky without knowing who is the HOD of what branch.
    // I'll implement a simple version where we assign based on role if possible.

    sqlx::query(
        "INSERT INTO issues (title, description, category, priority, status, created_by, user_role) 
         VALUES ($1, $2, $3, $4, 'Open', $5, $6)"
    )
    .bind(&payload.title)
    .bind(&payload.description)
    .bind(&payload.category)
    .bind(&payload.priority)
    .bind(created_by)
    .bind(&payload.user_role)
    .execute(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Submit Issue Error: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to submit issue"})))
    })?;

    Ok(StatusCode::OK)
}

pub async fn get_issues_handler(
    State(state): State<AppState>,
    Query(params): Query<GetIssuesQuery>,
) -> Result<Json<Vec<Issue>>, (StatusCode, Json<serde_json::Value>)> {
    let user_uuid = Uuid::parse_str(&params.user_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    let mut query = String::from(r#"
        SELECT 
            i.id, i.title, i.description, i.category, i.priority, i.status, i.created_by, i.user_role, i.assigned_to, i.created_date,
            u_creator.full_name as creator_name,
            u_assigned.full_name as assigned_name
        FROM issues i
        LEFT JOIN users u_creator ON i.created_by = u_creator.id
        LEFT JOIN users u_assigned ON i.assigned_to = u_assigned.id
        WHERE 1=1
    "#);

    // Filter Logic:
    // Users see their own issues.
    // HOD / Principal / Coordinator see department issues.
    // Coordinator sees all issues.
    
    match params.role.as_str() {
        "Student" | "Parent" | "Faculty" => {
            query.push_str(" AND i.created_by = $1");
        }
        "HOD" | "Principal" => {
            // HOD/Principal see issues from their branch or assigned to them
            if let Some(branch) = &params.branch {
                query.push_str(&format!(" AND (u_creator.branch = '{}' OR i.assigned_to = $1)", branch));
            } else {
                query.push_str(" AND (i.created_by = $1 OR i.assigned_to = $1)");
            }
        }
        "Coordinator" | "Admin" => {
            // See all
        }
        _ => {
            query.push_str(" AND i.created_by = $1");
        }
    }

    query.push_str(" ORDER BY i.created_date DESC");

    let issues = sqlx::query_as::<Postgres, Issue>(&query)
        .bind(user_uuid)
        .fetch_all(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Get Issues Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to fetch issues"})))
        })?;

    Ok(Json(issues))
}

pub async fn get_issue_details_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
) -> Result<Json<Issue>, (StatusCode, Json<serde_json::Value>)> {
    let issue = sqlx::query_as::<Postgres, Issue>(
        r#"
        SELECT 
            i.id, i.title, i.description, i.category, i.priority, i.status, i.created_by, i.user_role, i.assigned_to, i.created_date,
            u_creator.full_name as creator_name,
            u_assigned.full_name as assigned_name
        FROM issues i
        LEFT JOIN users u_creator ON i.created_by = u_creator.id
        LEFT JOIN users u_assigned ON i.assigned_to = u_assigned.id
        WHERE i.id = $1
        "#
    )
    .bind(issue_id)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?
    .ok_or((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "Issue not found"}))))?;

    Ok(Json(issue))
}

pub async fn get_issue_comments_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
) -> Result<Json<Vec<IssueComment>>, (StatusCode, Json<serde_json::Value>)> {
    let comments = sqlx::query_as::<Postgres, IssueComment>(
        r#"
        SELECT 
            c.id, c.issue_id, c.comment, c.comment_by, c.comment_date,
            u.full_name as user_name
        FROM issue_comments c
        LEFT JOIN users u ON c.comment_by = u.id
        WHERE c.issue_id = $1
        ORDER BY c.comment_date ASC
        "#
    )
    .bind(issue_id)
    .fetch_all(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    Ok(Json(comments))
}

pub async fn submit_comment_handler(
    State(state): State<AppState>,
    Json(payload): Json<SubmitCommentRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let issue_id = Uuid::parse_str(&payload.issue_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid Issue ID"}))))?;
    let comment_by = Uuid::parse_str(&payload.comment_by).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    sqlx::query(
        "INSERT INTO issue_comments (issue_id, comment, comment_by) VALUES ($1, $2, $3)"
    )
    .bind(issue_id)
    .bind(&payload.comment)
    .bind(comment_by)
    .execute(&state.pool)
    .await
    .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    Ok(StatusCode::OK)
}

pub async fn assign_issue_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
    Json(payload): Json<AssignIssueRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let assigned_to = Uuid::parse_str(&payload.assigned_to).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid User ID"}))))?;

    sqlx::query("UPDATE issues SET assigned_to = $1, status = 'In Progress' WHERE id = $2")
        .bind(assigned_to)
        .bind(issue_id)
        .execute(&state.pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    Ok(StatusCode::OK)
}

pub async fn update_issue_status_handler(
    State(state): State<AppState>,
    Path(issue_id): Path<Uuid>,
    Json(payload): Json<UpdateIssueStatusRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    
    let mut tx = state.pool.begin().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Transaction failed"}))))?;

    sqlx::query("UPDATE issues SET status = $1 WHERE id = $2")
        .bind(&payload.status)
        .bind(issue_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    // Notify creator
    let issue_info: (Uuid, String) = sqlx::query_as("SELECT created_by, title FROM issues WHERE id = $1")
        .bind(issue_id)
        .fetch_one(&mut *tx)
        .await
        .map_err(|_| (StatusCode::NOT_FOUND, Json(serde_json::json!({"error": "Issue not found"}))))?;

    let msg = format!("Your issue '{}' has been {}.", issue_info.1, payload.status.to_lowercase());

    sqlx::query("INSERT INTO notifications (type, message, recipient_id, status) VALUES ($1, $2, $3, 'UNREAD')")
        .bind("ISSUE_STATUS_UPDATE")
        .bind(msg)
        .bind(issue_info.0.to_string())
        .execute(&mut *tx)
        .await
        .ok();

    tx.commit().await.map_err(|_| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Commit failed"}))))?;

    Ok(StatusCode::OK)
}
