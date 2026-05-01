use sqlx::{PgPool};
use uuid::Uuid;

pub async fn approve_hod(pool: &PgPool, user_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE users SET is_approved = TRUE WHERE id = $1 AND role = 'HOD'").bind(user_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn delete_hod(pool: &PgPool, user_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM users WHERE id = $1 AND role = 'HOD'").bind(user_id).execute(pool).await.map(|r| r.rows_affected())
}
