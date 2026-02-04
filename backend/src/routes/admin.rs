use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
use sqlx::Postgres;
use crate::models::{AppState, AdminUserQuery, AdminUserDTO, AdminStats, AdminApprovalRequest}; // Import needed structs

pub async fn get_admin_users_handler(
    State(state): State<AppState>,
    Query(params): Query<AdminUserQuery>,
) -> Result<Json<Vec<AdminUserDTO>>, StatusCode> {
    let mut query = "SELECT id, full_name, role, login_id, branch, year, is_approved FROM users".to_string();
    let mut conditions = Vec::new();

    if let Some(category) = &params.category {
        match category.as_str() {
            "student" => conditions.push("role = 'Student'".to_string()),
            "parent" => conditions.push("role = 'Parent'".to_string()),
            "staff" => conditions.push("role IN ('Faculty', 'HOD', 'Principal', 'Coordinator', 'Admin')".to_string()),
            _ => {}
        }
    } else if let Some(role) = &params.role {
        if !role.is_empty() {
             conditions.push(format!("role = '{}'", role));
        }
    }

    if let Some(branch) = &params.branch {
        if !branch.is_empty() {
             conditions.push(format!("branch ILIKE '{}'", branch.trim()));
        }
    }

    if let Some(year) = &params.year {
        if !year.is_empty() {
             conditions.push(format!("year ILIKE '{}%'", year.trim())); 
        }
    }

    if let Some(search) = &params.search {
        if !search.is_empty() {
            conditions.push(format!("(full_name ILIKE '%{}%' OR login_id ILIKE '%{}%')", search, search));
        }
    }
    
    if let Some(approved) = params.is_approved {
        conditions.push(format!("is_approved = {}", approved));
    }

    if !conditions.is_empty() {
        query.push_str(" WHERE ");
        query.push_str(&conditions.join(" AND "));
    }
    
    query.push_str(" ORDER BY created_at DESC LIMIT 100");

    let users = sqlx::query_as::<Postgres, AdminUserDTO>(&query)
        .fetch_all(&state.pool)
        .await
        .map_err(|e| {
            eprintln!("Admin Fetch Users Error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    Ok(Json(users))
}

pub async fn get_admin_stats_handler(
    State(state): State<AppState>,
) -> Result<Json<AdminStats>, StatusCode> {
    let total_users: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users").fetch_one(&state.pool).await.unwrap_or(0);
    let pending_approvals: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE is_approved = FALSE AND role = 'Coordinator'").fetch_one(&state.pool).await.unwrap_or(0);
    let total_students: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE role = 'Student'").fetch_one(&state.pool).await.unwrap_or(0);
    let total_faculty: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE role = 'Faculty'").fetch_one(&state.pool).await.unwrap_or(0);

    Ok(Json(AdminStats {
        total_users,
        pending_approvals,
        total_students,
        total_faculty,
    }))
}

pub async fn admin_approve_user_handler(
    State(state): State<AppState>,
    Json(payload): Json<AdminApprovalRequest>,
) -> Result<StatusCode, StatusCode> {
    if payload.action == "APPROVE" {
        sqlx::query("UPDATE users SET is_approved = TRUE WHERE id = $1")
            .bind(payload.user_id)
            .execute(&state.pool)
            .await
            .map_err(|e| {
                eprintln!("Admin Approve Error: {:?}", e);
                StatusCode::INTERNAL_SERVER_ERROR
            })?;
    } else if payload.action == "REJECT" || payload.action == "DELETE" {
         sqlx::query("DELETE FROM users WHERE id = $1")
            .bind(payload.user_id)
            .execute(&state.pool)
            .await
            .map_err(|e| {
                eprintln!("Admin Delete Error: {:?}", e);
                StatusCode::INTERNAL_SERVER_ERROR
            })?;
    }
    Ok(StatusCode::OK)
}
