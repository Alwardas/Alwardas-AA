use sqlx::{PgPool, Postgres, Row, QueryBuilder};
use uuid::Uuid;
use crate::models::{
    StudentDetails, ParentRequest, ParentRequestQuery
};

pub async fn find_parent_basics_by_id(pool: &PgPool, user_uuid: Uuid) -> Result<Option<(String, String, Option<String>, Option<String>)>, sqlx::Error> {
    sqlx::query("SELECT full_name, login_id, phone_number, email FROM users WHERE id = $1")
        .bind(user_uuid)
        .fetch_optional(pool)
        .await
        .map(|opt| opt.map(|r| (
            r.get("full_name"),
            r.get("login_id"),
            r.get("phone_number"),
            r.get("email")
        )))
}

pub async fn find_student_by_parent_login(pool: &PgPool, parent_login: &str) -> Result<Option<StudentDetails>, sqlx::Error> {
    sqlx::query_as::<Postgres, StudentDetails>(
        "SELECT u.id, u.full_name, u.login_id, u.branch, u.year, u.semester, u.batch_no 
         FROM users u
         JOIN parent_student ps ON u.login_id = ps.student_id
         WHERE ps.parent_id = $1 AND u.role = 'Student'
         LIMIT 1"
    )
    .bind(parent_login)
    .fetch_optional(pool)
    .await
}

pub async fn find_student_by_login_id(pool: &PgPool, login_id: &str) -> Result<Option<StudentDetails>, sqlx::Error> {
    sqlx::query_as::<Postgres, StudentDetails>("SELECT id, full_name, login_id, branch, year, semester, batch_no FROM users WHERE login_id = $1 AND role = 'Student'")
        .bind(login_id).fetch_optional(pool).await
}

pub async fn get_user_branch_by_id(pool: &PgPool, user_uuid: Uuid) -> Result<Option<String>, sqlx::Error> {
    sqlx::query_scalar("SELECT branch FROM users WHERE id = $1").bind(user_uuid).fetch_optional(pool).await
}

pub async fn find_hod_id_by_branch(pool: &PgPool, branch: &str) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar("SELECT id FROM users WHERE role = 'HOD' AND branch = $1 LIMIT 1").bind(branch).fetch_optional(pool).await
}

pub async fn find_coordinator_id_by_branch(pool: &PgPool, branch: &str) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar("SELECT id FROM users WHERE role = 'Coordinator' AND branch = $1 LIMIT 1").bind(branch).fetch_optional(pool).await
}

pub async fn find_principal_id(pool: &PgPool) -> Result<Option<Uuid>, sqlx::Error> {
    sqlx::query_scalar("SELECT id FROM users WHERE role = 'Principal' LIMIT 1").fetch_optional(pool).await
}

pub async fn insert_parent_request(pool: &PgPool, parent_id: Uuid, student_id: Uuid, r_type: &str, subject: &str, desc: &str, duration: &str, assigned_to: Option<Uuid>, voice_note: Option<&str>) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO parent_requests (parent_id, student_id, request_type, subject, description, date_duration, status, assigned_to, voice_note) VALUES ($1, $2, $3, $4, $5, $6, 'Pending', $7, $8)")
        .bind(parent_id).bind(student_id).bind(r_type).bind(subject).bind(desc).bind(duration).bind(assigned_to).bind(voice_note)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_parent_requests(pool: &PgPool, params: ParentRequestQuery) -> Result<Vec<ParentRequest>, sqlx::Error> {
    let mut query = QueryBuilder::new(r#"
        SELECT 
            pr.id, pr.parent_id, pr.student_id, pr.request_type, pr.subject, pr.description, pr.date_duration, pr.status, pr.created_at, pr.updated_at, pr.assigned_to, pr.voice_note,
            u_parent.full_name as parent_name,
            u_parent.role as parent_role,
            u_student.full_name as student_name,
            u_student.login_id as student_login_id,
            u_assigned.full_name as assigned_name
        FROM parent_requests pr
        LEFT JOIN users u_parent ON pr.parent_id = u_parent.id
        LEFT JOIN users u_student ON pr.student_id = u_student.id
        LEFT JOIN users u_assigned ON pr.assigned_to = u_assigned.id
        WHERE 1=1
    "#);

    if let Some(parent_id) = &params.parent_id {
        if let Ok(p_uuid) = Uuid::parse_str(parent_id) { query.push(" AND pr.parent_id = "); query.push_bind(p_uuid); }
        else { query.push(" AND pr.parent_id = (SELECT id FROM users WHERE login_id = "); query.push_bind(parent_id); query.push(" LIMIT 1)"); }
    }

    if let Some(student_id) = &params.student_id {
        if let Ok(s_uuid) = Uuid::parse_str(student_id) { query.push(" AND pr.student_id = "); query.push_bind(s_uuid); }
        else { query.push(" AND pr.student_id = (SELECT id FROM users WHERE login_id = "); query.push_bind(student_id); query.push(" LIMIT 1)"); }
    }

    if let Some(role) = &params.role {
        match role.as_str() {
            "Faculty" | "HOD" | "Coordinator" | "Incharge" => if let Some(uid) = &params.user_id {
                let u_uuid_opt = if let Ok(u) = Uuid::parse_str(uid) { Some(u) } else { 
                    sqlx::query_scalar("SELECT id FROM users WHERE login_id = $1").bind(uid).fetch_optional(pool).await.unwrap_or(None) 
                };
                if let Some(u_uuid) = u_uuid_opt {
                     query.push(" AND (pr.assigned_to = "); query.push_bind(u_uuid);
                     query.push(" OR (pr.assigned_to IS NULL AND u_student.branch ILIKE "); query.push_bind(params.branch.clone().unwrap_or_default().trim().to_string()); query.push("))");
                } else if let Some(branch) = &params.branch {
                    query.push(" AND (u_student.branch ILIKE "); query.push_bind(branch.trim()); query.push(")");
                }
            } else if let Some(branch) = &params.branch {
                query.push(" AND (u_student.branch ILIKE "); query.push_bind(branch.trim()); query.push(")");
            },
            "Principal" | "Admin" => if let Some(branch) = &params.branch { query.push(" AND (u_student.branch = "); query.push_bind(branch); query.push(")"); },
            _ => {}
        }
    }

    query.push(" ORDER BY pr.created_at DESC");
    query.build_query_as::<ParentRequest>().fetch_all(pool).await
}

pub async fn update_parent_request_status(pool: &PgPool, request_id: Uuid, status: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE parent_requests SET status = $1, updated_at = NOW() WHERE id = $2").bind(status).bind(request_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn delete_parent_request(pool: &PgPool, request_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM parent_requests WHERE id = $1").bind(request_id).execute(pool).await.map(|r| r.rows_affected())
}
