use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
// No sqlx imports needed here as we use query_as with inferred database type or models imported elsewhere if needed.
// Actually, query_as often needs the trait, but crate::models might bring it in.
// Let's just remove the unused ones.
use crate::models::{AppState, ProfileQuery, ParentProfileResponse, StudentDetails};
use crate::routes::faculty::resolve_user_id;
use uuid::Uuid;

pub async fn get_parent_profile_handler(
    State(state): State<AppState>,
    Query(params): Query<ProfileQuery>,
) -> Result<Json<ParentProfileResponse>, StatusCode> {
    
    #[derive(sqlx::FromRow)]
    struct ParentData {
        full_name: String,
        login_id: String,
        phone_number: Option<String>,
        email: Option<String>,
    }

    let user_uuid = resolve_user_id(&params.user_id, "Parent", &state.pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;

    let parent_opt = sqlx::query_as::<_, ParentData>(
        "SELECT full_name, login_id, phone_number, email FROM users WHERE id = $1"
    )
    .bind(user_uuid)
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| {
        eprintln!("Parent Fetch Error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    let parent = match parent_opt {
        Some(p) => p,
        None => return Err(StatusCode::NOT_FOUND),
    };

    let student_opt = sqlx::query_as::<_, StudentDetails>(
        "SELECT u.full_name, u.login_id, u.branch, u.year, u.semester, u.batch_no 
         FROM users u
         JOIN parent_student ps ON u.login_id = ps.student_id
         WHERE ps.parent_id = $1 AND u.role = 'Student'
         LIMIT 1"
    )
    .bind(&parent.login_id)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    let final_student_opt = if student_opt.is_none() {
        // Fallback for legacy ones without explicit relationship mapping
        let legacy_id = if parent.login_id.starts_with("P-") {
            parent.login_id[2..].to_string()
        } else {
            parent.login_id.clone() 
        };
        
        sqlx::query_as::<_, StudentDetails>(
            "SELECT full_name, login_id, branch, year, semester, batch_no FROM users WHERE login_id = $1 AND role = 'Student'"
        )
        .bind(&legacy_id)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None)
    } else {
        student_opt
    };

    Ok(Json(ParentProfileResponse {
        full_name: parent.full_name,
        phone_number: parent.phone_number,
        email: parent.email,
        student: final_student_opt,
    }))
}

pub async fn submit_parent_request_handler(
    State(state): State<AppState>,
    Json(payload): Json<crate::models::SubmitParentRequest>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    let parent_uuid = Uuid::parse_str(&payload.parent_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid Parent ID"}))))?;
    let student_uuid = Uuid::parse_str(&payload.student_id).map_err(|_| (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": "Invalid Student ID"}))))?;

    let student_branch: Option<String> = sqlx::query_scalar("SELECT branch FROM users WHERE id = $1")
        .bind(student_uuid)
        .fetch_optional(&state.pool)
        .await
        .unwrap_or(None);
        
    let mut target_uuids = std::collections::HashSet::new();

    if let Some(fac_ids) = &payload.target_faculty_ids {
        for f_id in fac_ids {
            if let Ok(u) = Uuid::parse_str(f_id) {
                target_uuids.insert(u);
            }
        }
    }

    if let Some(roles) = &payload.target_roles {
        for role in roles {
            match role.as_str() {
                "HOD" => {
                    if let Some(ref branch) = student_branch {
                        let hod_id: Option<Uuid> = sqlx::query_scalar("SELECT id FROM users WHERE role = 'HOD' AND branch = $1 LIMIT 1")
                            .bind(branch)
                            .fetch_optional(&state.pool).await.unwrap_or(None);
                        if let Some(id) = hod_id { target_uuids.insert(id); }
                    }
                },
                "Coordinator" => {
                    if let Some(ref branch) = student_branch {
                         let coord_id: Option<Uuid> = sqlx::query_scalar("SELECT id FROM users WHERE role = 'Coordinator' AND branch = $1 LIMIT 1")
                            .bind(branch)
                            .fetch_optional(&state.pool).await.unwrap_or(None);
                        if let Some(id) = coord_id { target_uuids.insert(id); }
                    }
                },
                "Principal" => {
                    let prin_id: Option<Uuid> = sqlx::query_scalar("SELECT id FROM users WHERE role = 'Principal' LIMIT 1")
                        .fetch_optional(&state.pool).await.unwrap_or(None);
                    if let Some(id) = prin_id { target_uuids.insert(id); }
                },
                _ => {}
            }
        }
    }

    if target_uuids.is_empty() {
        sqlx::query(
            "INSERT INTO parent_requests (parent_id, student_id, request_type, subject, description, date_duration, status) 
             VALUES ($1, $2, $3, $4, $5, $6, 'Pending')"
        )
        .bind(parent_uuid)
        .bind(student_uuid)
        .bind(&payload.request_type)
        .bind(&payload.subject)
        .bind(&payload.description)
        .bind(&payload.date_duration)
        .execute(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Submit Parent Request Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to submit request"})))
        })?;
    } else {
        for assigned_to in target_uuids {
            sqlx::query(
                 "INSERT INTO parent_requests (parent_id, student_id, request_type, subject, description, date_duration, status, assigned_to) 
                  VALUES ($1, $2, $3, $4, $5, $6, 'Pending', $7)"
             )
             .bind(parent_uuid)
             .bind(student_uuid)
             .bind(&payload.request_type)
             .bind(&payload.subject)
             .bind(&payload.description)
             .bind(&payload.date_duration)
             .bind(assigned_to)
             .execute(&state.pool)
             .await
             .map_err(|e| {
                 eprintln!("Submit Parent Request Error: {:?}", e);
                 (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to submit request"})))
             })?;
        }
    }

    Ok(StatusCode::OK)
}

pub async fn get_parent_requests_handler(
    State(state): State<AppState>,
    Query(params): Query<crate::models::ParentRequestQuery>,
) -> Result<Json<Vec<crate::models::ParentRequest>>, (StatusCode, Json<serde_json::Value>)> {
    
    let mut query = sqlx::QueryBuilder::new(r#"
        SELECT 
            pr.id, pr.parent_id, pr.student_id, pr.request_type, pr.subject, pr.description, pr.date_duration, pr.status, pr.created_at, pr.updated_at, pr.assigned_to,
            u_parent.full_name as parent_name,
            u_student.full_name as student_name,
            u_assigned.full_name as assigned_name
        FROM parent_requests pr
        LEFT JOIN users u_parent ON pr.parent_id = u_parent.id
        LEFT JOIN users u_student ON pr.student_id = u_student.id
        LEFT JOIN users u_assigned ON pr.assigned_to = u_assigned.id
        WHERE 1=1
    "#);

    if let Some(parent_id) = &params.parent_id {
        if let Ok(p_uuid) = Uuid::parse_str(parent_id) {
            query.push(" AND pr.parent_id = ");
            query.push_bind(p_uuid);
        }
    }

    if let Some(student_id) = &params.student_id {
        if let Ok(s_uuid) = Uuid::parse_str(student_id) {
            query.push(" AND pr.student_id = ");
            query.push_bind(s_uuid);
        }
    }

    if let Some(role) = &params.role {
        match role.as_str() {
            "Faculty" | "HOD" | "Principal" | "Coordinator" => {
                if let Some(branch) = &params.branch {
                    query.push(" AND (u_student.branch = ");
                    query.push_bind(branch);
                    query.push(")");
                }
            }
            _ => {}
        }
    }

    query.push(" ORDER BY pr.created_at DESC");

    let requests = query.build_query_as::<crate::models::ParentRequest>()
        .fetch_all(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Get Parent Requests Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to fetch requests"})))
        })?;

    Ok(Json(requests))
}

pub async fn update_parent_request_status_handler(
    State(state): State<AppState>,
    axum::extract::Path(request_id): axum::extract::Path<Uuid>,
    Json(payload): Json<crate::models::UpdateParentRequestStatus>,
) -> Result<StatusCode, (StatusCode, Json<serde_json::Value>)> {
    
    sqlx::query("UPDATE parent_requests SET status = $1, updated_at = NOW() WHERE id = $2")
        .bind(&payload.status)
        .bind(request_id)
        .execute(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Update Parent Request Status Error: {:?}", e);
            (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": "Failed to update status"})))
        })?;

    Ok(StatusCode::OK)
}

