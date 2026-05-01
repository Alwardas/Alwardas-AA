use uuid::Uuid;
use axum::{http::StatusCode, Json};
use sqlx::{PgPool, Row};

pub async fn resolve_user_id(id_str: &str, role_hint: &str, pool: &PgPool) -> Result<Uuid, (StatusCode, Json<serde_json::Value>)> {
    if let Ok(u) = Uuid::parse_str(id_str) {
        return Ok(u);
    }

    let row = sqlx::query("SELECT id FROM users WHERE login_id = $1 AND role = $2")
        .bind(id_str)
        .bind(role_hint)
        .fetch_optional(pool)
        .await
        .map_err(|e| (StatusCode::INTERNAL_SERVER_ERROR, Json(serde_json::json!({"error": e.to_string()}))))?;

    match row {
        Some(r) => Ok(r.get("id")),
        None => Err((StatusCode::NOT_FOUND, Json(serde_json::json!({"error": format!("User not found with ID/Login ID: {}", id_str)})))),
    }
}
