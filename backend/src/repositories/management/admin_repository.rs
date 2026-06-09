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

pub async fn promote_students(pool: &PgPool, branch_filter: Option<&str>) -> Result<u64, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let mut affected: u64 = 0;

    let academic_year_label = format!("{}-{}", chrono::Utc::now().format("%Y"), (chrono::Utc::now() + chrono::Duration::days(365)).format("%y"));

    let branch_condition = if branch_filter.is_some() { "AND branch = $2" } else { "" };

    let q1_sql = format!("INSERT INTO student_academic_history (student_id, academic_year, study_year, semester) SELECT id, $1, '3rd Year', semester FROM users WHERE role = 'Student' AND year = '3rd Year' AND status = 'Active' {}", branch_condition);
    let u1_sql = format!("UPDATE users SET status = 'Graduated', year = 'Graduated', semester = NULL WHERE role = 'Student' AND year = '3rd Year' AND status = 'Active' {}", branch_condition);

    let q2_sql = format!("INSERT INTO student_academic_history (student_id, academic_year, study_year, semester) SELECT id, $1, '2nd Year', semester FROM users WHERE role = 'Student' AND year = '2nd Year' AND status = 'Active' {}", branch_condition);
    let u2_sql = format!("UPDATE users SET year = '3rd Year' WHERE role = 'Student' AND year = '2nd Year' AND status = 'Active' {}", branch_condition);

    let q3_sql = format!("INSERT INTO student_academic_history (student_id, academic_year, study_year, semester) SELECT id, $1, '1st Year', semester FROM users WHERE role = 'Student' AND year = '1st Year' AND status = 'Active' {}", branch_condition);
    let u3_sql = format!("UPDATE users SET year = '2nd Year' WHERE role = 'Student' AND year = '1st Year' AND status = 'Active' {}", branch_condition);

    if let Some(b) = branch_filter {
        sqlx::query(&q1_sql).bind(&academic_year_label).bind(b).execute(&mut *tx).await?;
        let u1 = sqlx::query(&u1_sql).bind(b).execute(&mut *tx).await?;
        affected += u1.rows_affected();

        sqlx::query(&q2_sql).bind(&academic_year_label).bind(b).execute(&mut *tx).await?;
        let u2 = sqlx::query(&u2_sql).bind(b).execute(&mut *tx).await?;
        affected += u2.rows_affected();

        sqlx::query(&q3_sql).bind(&academic_year_label).bind(b).execute(&mut *tx).await?;
        let u3 = sqlx::query(&u3_sql).bind(b).execute(&mut *tx).await?;
        affected += u3.rows_affected();
    } else {
        sqlx::query(&q1_sql).bind(&academic_year_label).execute(&mut *tx).await?;
        let u1 = sqlx::query(&u1_sql).execute(&mut *tx).await?;
        affected += u1.rows_affected();

        sqlx::query(&q2_sql).bind(&academic_year_label).execute(&mut *tx).await?;
        let u2 = sqlx::query(&u2_sql).execute(&mut *tx).await?;
        affected += u2.rows_affected();

        sqlx::query(&q3_sql).bind(&academic_year_label).execute(&mut *tx).await?;
        let u3 = sqlx::query(&u3_sql).execute(&mut *tx).await?;
        affected += u3.rows_affected();
    }

    tx.commit().await?;
    Ok(affected)
}
