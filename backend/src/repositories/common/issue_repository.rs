use sqlx::{PgPool, Postgres, QueryBuilder};
use uuid::Uuid;
use crate::models::{Issue, IssueComment, GetIssuesQuery};

pub async fn insert_issue(pool: &PgPool, title: &str, desc: &str, cat: &str, prio: &str, created_by: Uuid, role: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO issues (title, description, category, priority, status, created_by, user_role) VALUES ($1, $2, $3, $4, 'Open', $5, $6)")
        .bind(title).bind(desc).bind(cat).bind(prio).bind(created_by).bind(role)
        .execute(pool).await.map(|r| r.rows_affected())
}

pub async fn find_issues(pool: &PgPool, params: GetIssuesQuery, user_uuid: Uuid) -> Result<Vec<Issue>, sqlx::Error> {
    let mut query = QueryBuilder::new(r#"
        SELECT 
            i.id, i.title, i.description, i.category, i.priority, i.status, i.created_by, i.user_role, i.assigned_to, i.created_date,
            u_creator.full_name as creator_name,
            u_assigned.full_name as assigned_name
        FROM issues i
        LEFT JOIN users u_creator ON i.created_by = u_creator.id
        LEFT JOIN users u_assigned ON i.assigned_to = u_assigned.id
        WHERE 1=1
    "#);

    match params.role.as_str() {
        "Student" | "Parent" => {
            query.push(" AND i.created_by = ");
            query.push_bind(user_uuid);
        }
        "Faculty" => {
            query.push(" AND (i.created_by = ");
            query.push_bind(user_uuid);
            query.push(" OR i.assigned_to = ");
            query.push_bind(user_uuid);
            query.push(")");
        }
        "HOD" => {
            if let Some(branch) = &params.branch {
                query.push(" AND (u_creator.branch = ");
                query.push_bind(branch);
                query.push(" OR i.assigned_to = ");
                query.push_bind(user_uuid);
                query.push(" OR u_creator.role = 'Coordinator')");
            } else {
                query.push(" AND (i.created_by = ");
                query.push_bind(user_uuid);
                query.push(" OR i.assigned_to = ");
                query.push_bind(user_uuid);
                query.push(" OR u_creator.role = 'Coordinator')");
            }
        }
        "Principal" | "Coordinator" | "Admin" => {}
        _ => {
            query.push(" AND i.created_by = ");
            query.push_bind(user_uuid);
        }
    }

    query.push(" ORDER BY i.created_date DESC");
    query.build_query_as::<Issue>().fetch_all(pool).await
}

pub async fn find_issue_by_id(pool: &PgPool, issue_id: Uuid) -> Result<Option<Issue>, sqlx::Error> {
    sqlx::query_as::<Postgres, Issue>(
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
    .bind(issue_id).fetch_optional(pool).await
}

pub async fn find_issue_comments(pool: &PgPool, issue_id: Uuid) -> Result<Vec<IssueComment>, sqlx::Error> {
    sqlx::query_as::<Postgres, IssueComment>(
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
    .bind(issue_id).fetch_all(pool).await
}

pub async fn insert_comment(pool: &PgPool, issue_id: Uuid, comment: &str, comment_by: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO issue_comments (issue_id, comment, comment_by) VALUES ($1, $2, $3)")
        .bind(issue_id).bind(comment).bind(comment_by).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_issue_assignment(pool: &PgPool, issue_id: Uuid, assigned_to: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE issues SET assigned_to = $1, status = 'In Progress' WHERE id = $2")
        .bind(assigned_to).bind(issue_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn update_issue_status(executor: &mut sqlx::Transaction<'_, Postgres>, issue_id: Uuid, status: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE issues SET status = $1 WHERE id = $2")
        .bind(status).bind(issue_id).execute(&mut **executor).await.map(|r| r.rows_affected())
}

pub async fn find_issue_basic_info(executor: &mut sqlx::Transaction<'_, Postgres>, issue_id: Uuid) -> Result<(Uuid, String), sqlx::Error> {
    sqlx::query_as("SELECT created_by, title FROM issues WHERE id = $1").bind(issue_id).fetch_one(&mut **executor).await
}

pub async fn insert_notification(executor: &mut sqlx::Transaction<'_, Postgres>, n_type: &str, message: &str, recipient_id: &str) -> Result<u64, sqlx::Error> {
    sqlx::query("INSERT INTO notifications (type, message, recipient_id, status) VALUES ($1, $2, $3, 'UNREAD')")
        .bind(n_type).bind(message).bind(recipient_id).execute(&mut **executor).await.map(|r| r.rows_affected())
}

pub async fn delete_issue_comments(pool: &PgPool, issue_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM issue_comments WHERE issue_id = $1").bind(issue_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn delete_issue(pool: &PgPool, issue_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM issues WHERE id = $1").bind(issue_id).execute(pool).await.map(|r| r.rows_affected())
}
