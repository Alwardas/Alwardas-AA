use sqlx::{PgPool, Postgres, QueryBuilder};
use uuid::Uuid;
use crate::models::{Notification, NotificationQuery};

pub async fn find_notifications(pool: &PgPool, params: NotificationQuery) -> Result<Vec<Notification>, sqlx::Error> {
    let mut query_builder = QueryBuilder::<Postgres>::new(
        "SELECT id, type, message, sender_id, recipient_id, branch, status, created_at FROM notifications WHERE 1=1"
    );

    if let Some(role) = &params.role {
        match role.as_str() {
            "Student" => {
                query_builder.push(" AND (recipient_id = ");
                query_builder.push_bind(params.user_id.clone().unwrap_or_default());
                query_builder.push(" OR recipient_id = 'STUDENT_RECIPIENT' OR recipient_id IS NULL)");
            },
            "Faculty" => {
                query_builder.push(" AND (recipient_id = ");
                query_builder.push_bind(params.user_id.clone().unwrap_or_default());
                query_builder.push(" OR recipient_id = 'FACULTY_RECIPIENT' OR (recipient_id IS NULL AND (branch = ");
                query_builder.push_bind(params.branch.clone().unwrap_or_default());
                query_builder.push(" OR branch IS NULL)))");
            },
            "Parent" => {
                query_builder.push(" AND (recipient_id = ");
                query_builder.push_bind(params.user_id.clone().unwrap_or_default());
                query_builder.push(" OR recipient_id = 'PARENT_RECIPIENT' OR recipient_id IS NULL)");
            },
            "HOD" => {
                if let Some(branch) = &params.branch {
                    query_builder.push(" AND ((recipient_id = 'HOD_RECIPIENT' AND (branch = ");
                    query_builder.push_bind(branch);
                    query_builder.push(" OR branch IS NULL)) OR (recipient_id IS NULL AND (branch = ");
                    query_builder.push_bind(branch);
                    query_builder.push(" OR branch IS NULL)))");
                } else if let Some(uid) = &params.user_id {
                    query_builder.push(" AND (recipient_id = ");
                    query_builder.push_bind(uid);
                    query_builder.push(" OR recipient_id = 'HOD_RECIPIENT' OR recipient_id IS NULL)");
                }
            },
            "Principal" => {
                query_builder.push(" AND (recipient_id = 'PRINCIPAL_RECIPIENT' OR (recipient_id IS NULL AND branch IS NULL))");
            },
            "Coordinator" | "Incharge" => {
                query_builder.push(" AND (recipient_id = 'COORDINATOR_RECIPIENT' OR (recipient_id IS NULL AND branch IS NULL))");
            },
            "Admin" => {
                query_builder.push(" AND (recipient_id = 'ADMIN_RECIPIENT' OR recipient_id IS NULL)");
            },
            _ => {
                if let Some(uid) = &params.user_id {
                    query_builder.push(" AND (recipient_id = ");
                    query_builder.push_bind(uid);
                    query_builder.push(" OR (recipient_id IS NULL AND (branch = ");
                    query_builder.push_bind(params.branch.clone().unwrap_or_default());
                    query_builder.push(" OR branch IS NULL)))");
                }
            }
        }
    } else if let Some(uid) = &params.user_id {
        query_builder.push(" AND recipient_id = ");
        query_builder.push_bind(uid);
    }
    
    query_builder.push(" ORDER BY created_at DESC");

    query_builder.build_query_as::<Notification>()
        .fetch_all(pool)
        .await
}

pub async fn delete_notifications(pool: &PgPool, ids: Vec<Uuid>) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM notifications WHERE id = ANY($1)")
        .bind(&ids)
        .execute(pool)
        .await
        .map(|r| r.rows_affected())
}
