use sqlx::{PgPool, Postgres, QueryBuilder};
use uuid::Uuid;
use crate::models::{AdminUserQuery, AdminUserDTO, AdminStats};

pub async fn find_users(pool: &PgPool, params: AdminUserQuery) -> Result<Vec<AdminUserDTO>, sqlx::Error> {
    let mut query = QueryBuilder::<Postgres>::new("SELECT id, full_name, role, login_id, branch, year, is_approved FROM users");
    
    let mut has_where = false;

    if let Some(category) = &params.category {
        query.push(if !has_where { " WHERE " } else { " AND " });
        match category.as_str() {
            "student" => query.push("role = 'Student'"),
            "parent" => query.push("role = 'Parent'"),
            "staff" => query.push("role IN ('Faculty', 'HOD', 'Principal', 'Coordinator', 'Admin')"),
            _ => &mut query
        };
        has_where = true;
    } else if let Some(role) = &params.role {
        if !role.is_empty() {
            query.push(if !has_where { " WHERE " } else { " AND " });
            query.push("role = ");
            query.push_bind(role);
            has_where = true;
        }
    }

    if let Some(branch) = &params.branch {
        if !branch.is_empty() {
            query.push(if !has_where { " WHERE " } else { " AND " });
            query.push("branch ILIKE ");
            query.push_bind(format!("{}", branch.trim()));
            has_where = true;
        }
    }

    if let Some(year) = &params.year {
        if !year.is_empty() {
            query.push(if !has_where { " WHERE " } else { " AND " });
            query.push("year ILIKE ");
            query.push_bind(format!("{}%", year.trim()));
            has_where = true;
        }
    }

    if let Some(search) = &params.search {
        if !search.is_empty() {
            query.push(if !has_where { " WHERE " } else { " AND " });
            query.push("(full_name ILIKE ");
            query.push_bind(format!("%{}%", search));
            query.push(" OR login_id ILIKE ");
            query.push_bind(format!("%{}%", search));
            query.push(")");
            has_where = true;
        }
    }

    if let Some(approved) = params.is_approved {
        query.push(if !has_where { " WHERE " } else { " AND " });
        query.push("is_approved = ");
        query.push_bind(approved);
    }

    query.push(" ORDER BY created_at DESC LIMIT 100");

    query.build_query_as::<AdminUserDTO>().fetch_all(pool).await
}

pub async fn get_admin_stats(pool: &PgPool) -> Result<AdminStats, sqlx::Error> {
    let total_users: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users").fetch_one(pool).await.unwrap_or(0);
    let pending_approvals: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE is_approved = FALSE AND role = 'Coordinator'").fetch_one(pool).await.unwrap_or(0);
    let total_students: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE role = 'Student'").fetch_one(pool).await.unwrap_or(0);
    let total_faculty: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE role = 'Faculty'").fetch_one(pool).await.unwrap_or(0);

    Ok(AdminStats { total_users, pending_approvals, total_students, total_faculty })
}

pub async fn approve_user(pool: &PgPool, user_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("UPDATE users SET is_approved = TRUE WHERE id = $1").bind(user_id).execute(pool).await.map(|r| r.rows_affected())
}

pub async fn delete_user(pool: &PgPool, user_id: Uuid) -> Result<u64, sqlx::Error> {
    sqlx::query("DELETE FROM users WHERE id = $1").bind(user_id).execute(pool).await.map(|r| r.rows_affected())
}
