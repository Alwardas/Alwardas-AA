use sqlx::{PgPool, Postgres, Row};
use uuid::Uuid;
use crate::models::{LoginRequest, SignupRequest, AuthResponse, ProfileQuery, CheckUserQuery, ForgotPasswordRequest, ResetResponse, ChangePasswordRequest, UpdateUserRequest};

#[derive(sqlx::FromRow)]
pub struct UserRow {
    pub id: uuid::Uuid,
    pub full_name: String,
    pub role: String,
    pub password_hash: String,
    pub is_approved: Option<bool>,
    pub login_id: String,
    pub branch: Option<String>,
    pub year: Option<String>,
    pub semester: Option<String>,
    pub batch_no: Option<String>,
    pub section: Option<String>,
}

pub async fn find_user_by_login_id(pool: &PgPool, login_id: &str) -> Result<Option<UserRow>, sqlx::Error> {
    sqlx::query_as::<Postgres, UserRow>(
        "SELECT id, full_name, role, password_hash, is_approved, login_id, branch, year, semester, batch_no, section FROM users WHERE LOWER(login_id) = $1"
    )
    .bind(login_id.to_lowercase())
    .fetch_optional(pool)
    .await
}

pub async fn find_user_id_by_login_id(pool: &PgPool, login_id: &str) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar("SELECT id FROM users WHERE login_id = $1")
        .bind(login_id)
        .fetch_optional(pool)
        .await
}

pub async fn find_user_by_login_id_and_role(pool: &PgPool, login_id: &str, role: &str) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar("SELECT id FROM users WHERE login_id = $1 AND role = $2")
        .bind(login_id)
        .bind(role)
        .fetch_optional(pool)
        .await
}

pub async fn delete_pending_profile_updates(pool: &PgPool, user_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM profile_update_requests WHERE user_id = $1 AND status = 'PENDING_USER_APPROVAL'")
        .bind(user_id)
        .execute(pool)
        .await
        .map(|r| r.rows_affected())
}

pub async fn insert_profile_update_request(pool: &PgPool, user_id: Uuid, new_data: serde_json::Value) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO profile_update_requests (user_id, new_data, status) VALUES ($1, $2, 'PENDING_USER_APPROVAL')")
        .bind(user_id)
        .bind(new_data)
        .execute(pool)
        .await
        .map(|r| r.rows_affected())
}

pub async fn insert_user(pool: &PgPool, payload: &SignupRequest, branch: Option<&str>, year: Option<&str>, semester: Option<&str>, batch: Option<&str>, section: &str, is_approved: bool) -> Result<Uuid, sqlx::Error> {
    sqlx::query_scalar(
        "INSERT INTO users (full_name, role, login_id, password_hash, branch, year, phone_number, dob, is_approved, experience, email, semester, batch_no, section, title) 
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8::DATE, $9, $10, $11, $12, $13, $14, $15) 
         RETURNING id"
    )
    .bind(&payload.full_name)
    .bind(&payload.role)
    .bind(payload.login_id.trim().to_lowercase())
    .bind(payload.password.trim())
    .bind(branch)
    .bind(year)
    .bind(&payload.phone_number)
    .bind(&payload.dob)
    .bind(is_approved)
    .bind(&payload.experience)
    .bind(&payload.email)
    .bind(semester)
    .bind(batch)
    .bind(section)
    .bind(&payload.title)
    .fetch_one(pool)
    .await
}

pub async fn insert_notification(pool: &PgPool, n_type: &str, message: String, sender_id: &str, branch: Option<&str>, recipient_id: Option<&str>) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO notifications (type, message, sender_id, branch, status, recipient_id) VALUES ($1, $2, $3, $4, 'UNREAD', $5)")
        .bind(n_type)
        .bind(message)
        .bind(sender_id)
        .bind(branch)
        .bind(recipient_id)
        .execute(pool)
        .await
        .map(|r| r.rows_affected())
}

pub async fn insert_parent_student_link(pool: &PgPool, parent_id: &str, student_id: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO parent_student (parent_id, student_id, relationship) VALUES ($1, $2, 'Parent') ON CONFLICT DO NOTHING")
        .bind(parent_id)
        .bind(student_id)
        .execute(pool)
        .await
        .map(|r| r.rows_affected())
}

pub async fn delete_auth_notifications(pool: &PgPool, sender_id: &str, n_type: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM notifications WHERE sender_id = $1 AND type = $2")
        .bind(sender_id)
        .bind(n_type)
        .execute(pool)
        .await
        .map(|r| r.rows_affected())
}

pub async fn delete_pending_updates(pool: &PgPool, user_id: Uuid, statuses: Vec<&str>) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM profile_update_requests WHERE user_id = $1 AND status = ANY($2)")
        .bind(user_id)
        .bind(&statuses)
        .execute(pool)
        .await
        .map(|r| r.rows_affected())
}

pub async fn find_pending_user_update(pool: &PgPool, user_id: Uuid) -> Result<Option<(Uuid, serde_json::Value)>, sqlx::Error> {
    let row = sqlx::query("SELECT id, new_data FROM profile_update_requests WHERE user_id = $1 AND status = 'PENDING_USER_APPROVAL'")
        .bind(user_id)
        .fetch_optional(pool)
        .await?;
    Ok(row.map(|r| (r.get("id"), r.get("new_data"))))
}

pub async fn update_user_from_signup(pool: &PgPool, user_id: Uuid, data: &SignupRequest, section: &str) -> Result<u64, sqlx::Error> {
    sqlx::query(
        "UPDATE users SET 
            full_name = $1, 
            password_hash = $2, 
            branch = COALESCE($3, branch), 
            year = COALESCE($4, year), 
            phone_number = $5, 
            dob = $6::DATE, 
            experience = $7, 
            email = $8,
            semester = COALESCE($9, semester), 
            section = $10
         WHERE id = $11"
    )
    .bind(&data.full_name)
    .bind(&data.password)
    .bind(&data.branch)
    .bind(&data.year)
    .bind(&data.phone_number)
    .bind(&data.dob)
    .bind(&data.experience)
    .bind(&data.email)
    .bind(&data.semester)
    .bind(section)
    .bind(user_id)
    .execute(pool)
    .await
    .map(|r| r.rows_affected())
}

pub async fn delete_profile_update_request(pool: &PgPool, id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM profile_update_requests WHERE id = $1").bind(id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_user_info_for_check(pool: &PgPool, login_id: &str) -> Result<Option<serde_json::Value>, sqlx::Error> {
    let row: Option<(String, Option<String>, Option<String>, Option<String>, Option<String>, Option<chrono::NaiveDate>, Option<String>)> = 
        sqlx::query_as("SELECT full_name, branch, year, phone_number, email, dob, role FROM users WHERE login_id = $1")
        .bind(login_id)
        .fetch_optional(pool)
        .await?;
    
    Ok(row.map(|(full_name, branch, year, phone, email, dob, role)| serde_json::json!({
        "exists": true,
        "fullName": full_name,
        "branch": branch,
        "year": year,
        "phone": phone,
        "email": email,
        "dob": dob,
        "role": role
    })))
}

pub async fn find_user_role_by_id_and_dob(pool: &PgPool, login_id: &str, dob: &str) -> Result<Option<String>, sqlx::Error> {
    sqlx::query_scalar("SELECT role FROM users WHERE login_id = $1 AND dob = $2::DATE")
        .bind(login_id)
        .bind(dob)
        .fetch_optional(pool)
        .await
}

pub async fn find_password_hash_by_id(pool: &PgPool, id: Uuid) -> Result<String, sqlx::Error> {
    sqlx::query_scalar("SELECT password_hash FROM users WHERE id = $1").bind(id).fetch_one(pool).await
}

pub async fn update_password(pool: &PgPool, id: Uuid, new_password: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE users SET password_hash = $1 WHERE id = $2").bind(new_password).bind(id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_user_fields(pool: &PgPool, payload: &UpdateUserRequest) -> Result<u64, sqlx::Error> {
    let user_id_uuid = Uuid::parse_str(&payload.user_id).unwrap_or_default();
    sqlx::query(
        "UPDATE users SET 
            full_name = COALESCE($1, full_name), 
            phone_number = COALESCE($2, phone_number), 
            email = COALESCE($3, email), 
            experience = COALESCE($4, experience), 
            dob = COALESCE($5::DATE, dob),
            branch = COALESCE($6, branch),
            year = COALESCE($7, year),
            semester = COALESCE($8, semester),
            batch_no = COALESCE($9, batch_no),
            login_id = COALESCE($10, login_id)
         WHERE id = $11"
    )
    .bind(&payload.full_name)
    .bind(&payload.phone_number)
    .bind(&payload.email)
    .bind(&payload.experience)
    .bind(&payload.dob)
    .bind(&payload.branch)
    .bind(&payload.year)
    .bind(&payload.semester)
    .bind(&payload.batch_no)
    .bind(&payload.login_id)
    .bind(user_id_uuid)
    .execute(pool)
    .await
    .map(|r| r.rows_affected())
}
