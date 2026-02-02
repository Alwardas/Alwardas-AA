use axum::{
    extract::{State, Query},
    Json,
    http::StatusCode,
};
// No sqlx imports needed here as we use query_as with inferred database type or models imported elsewhere if needed.
// Actually, query_as often needs the trait, but crate::models might bring it in.
// Let's just remove the unused ones.
use crate::models::{AppState, ProfileQuery, ParentProfileResponse, StudentDetails};

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

    let parent_opt = sqlx::query_as::<_, ParentData>(
        "SELECT full_name, login_id, phone_number, email FROM users WHERE id = $1"
    )
    .bind(params.user_id)
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

    let student_login_id = if parent.login_id.starts_with("P-") {
        parent.login_id[2..].to_string()
    } else {
        parent.login_id.clone() 
    };

    let student_opt = sqlx::query_as::<_, StudentDetails>(
        "SELECT full_name, login_id, branch, year, semester, batch_no FROM users WHERE login_id = $1"
    )
    .bind(&student_login_id)
    .fetch_optional(&state.pool)
    .await
    .unwrap_or(None);

    Ok(Json(ParentProfileResponse {
        full_name: parent.full_name,
        phone_number: parent.phone_number,
        email: parent.email,
        student: student_opt,
    }))
}
