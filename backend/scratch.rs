use sqlx::postgres::PgPoolOptions;

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    let url = "postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require";
    let pool = PgPoolOptions::new().connect(url).await?;

    println!("Fixing admission_year for graduated students...");
    
    // 3rd year students who just graduated (promoted in 2026) joined in 2023.
    let res = sqlx::query("UPDATE users SET admission_year = 2023 WHERE role = 'Student' AND status = 'Graduated' AND admission_year IS NULL")
        .execute(&pool).await?;
    println!("Updated {} graduated students to admission_year = 2023.", res.rows_affected());

    // Current 3rd year students (were 2nd year) joined in 2024
    let res = sqlx::query("UPDATE users SET admission_year = 2024 WHERE role = 'Student' AND year = '3rd Year' AND status = 'Active' AND admission_year IS NULL")
        .execute(&pool).await?;
    println!("Updated {} 3rd year students to admission_year = 2024.", res.rows_affected());

    // Current 2nd year students (were 1st year) joined in 2025
    let res = sqlx::query("UPDATE users SET admission_year = 2025 WHERE role = 'Student' AND year = '2nd Year' AND status = 'Active' AND admission_year IS NULL")
        .execute(&pool).await?;
    println!("Updated {} 2nd year students to admission_year = 2025.", res.rows_affected());

    println!("Fixing year and semester for graduated students...");
    let res = sqlx::query("UPDATE users SET year = 'Graduated', semester = NULL WHERE role = 'Student' AND status = 'Graduated'")
        .execute(&pool).await?;
    println!("Updated {} graduated students to year = 'Graduated', semester = NULL.", res.rows_affected());

    Ok(())
}
