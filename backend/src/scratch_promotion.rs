// Added to admin_repository.rs
pub async fn promote_students(pool: &PgPool) -> Result<u64, sqlx::Error> {
    let mut tx = pool.begin().await?;
    let mut affected: u64 = 0;

    // Get the current academic year representation. For now we will just use a generic term or current year.
    let academic_year_label = format!("{}-{}", chrono::Utc::now().format("%Y"), (chrono::Utc::now() + chrono::Duration::days(365)).format("%y"));

    // 1. History and promote 3rd Year -> Graduated
    let q1 = sqlx::query("INSERT INTO student_academic_history (student_id, academic_year, study_year, semester) SELECT id, $1, '3rd Year', semester FROM users WHERE role = 'Student' AND year = '3rd Year' AND status = 'Active'")
        .bind(&academic_year_label).execute(&mut *tx).await?;
    let u1 = sqlx::query("UPDATE users SET status = 'Graduated' WHERE role = 'Student' AND year = '3rd Year' AND status = 'Active'")
        .execute(&mut *tx).await?;
    affected += u1.rows_affected();

    // 2. History and promote 2nd Year -> 3rd Year
    let q2 = sqlx::query("INSERT INTO student_academic_history (student_id, academic_year, study_year, semester) SELECT id, $1, '2nd Year', semester FROM users WHERE role = 'Student' AND year = '2nd Year' AND status = 'Active'")
        .bind(&academic_year_label).execute(&mut *tx).await?;
    let u2 = sqlx::query("UPDATE users SET year = '3rd Year' WHERE role = 'Student' AND year = '2nd Year' AND status = 'Active'")
        .execute(&mut *tx).await?;
    affected += u2.rows_affected();

    // 3. History and promote 1st Year -> 2nd Year
    let q3 = sqlx::query("INSERT INTO student_academic_history (student_id, academic_year, study_year, semester) SELECT id, $1, '1st Year', semester FROM users WHERE role = 'Student' AND year = '1st Year' AND status = 'Active'")
        .bind(&academic_year_label).execute(&mut *tx).await?;
    let u3 = sqlx::query("UPDATE users SET year = '2nd Year' WHERE role = 'Student' AND year = '1st Year' AND status = 'Active'")
        .execute(&mut *tx).await?;
    affected += u3.rows_affected();

    tx.commit().await?;
    Ok(affected)
}
