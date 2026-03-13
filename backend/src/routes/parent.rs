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
