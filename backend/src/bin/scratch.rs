use sqlx::postgres::PgPoolOptions;

#[tokio::main]
async fn main() -> Result<(), sqlx::Error> {
    let url = "postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres?sslmode=require";
    let pool = PgPoolOptions::new().connect(url).await?;

    println!("Fixing semester for promoted students...");
    
    // 3rd year students who were recently promoted should be in 5th Semester.
    let res = sqlx::query("UPDATE users SET semester = '5th Semester' WHERE role = 'Student' AND year = '3rd Year' AND status = 'Active' AND (semester != '5th Semester' OR semester IS NULL)")
        .execute(&pool).await?;
    println!("Updated {} 3rd Year students to 5th Semester.", res.rows_affected());

    // 2nd year students who were recently promoted should be in 3rd Semester.
    let res = sqlx::query("UPDATE users SET semester = '3rd Semester' WHERE role = 'Student' AND year = '2nd Year' AND status = 'Active' AND (semester != '3rd Semester' OR semester IS NULL)")
        .execute(&pool).await?;
    println!("Updated {} 2nd Year students to 3rd Semester.", res.rows_affected());

    Ok(())
}
