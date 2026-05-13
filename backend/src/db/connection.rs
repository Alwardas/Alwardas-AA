use sqlx::{postgres::{PgPoolOptions, PgConnectOptions}, Pool, Postgres};
use std::str::FromStr;

pub async fn init_db() -> Pool<Postgres> {
    let raw_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    
    // Robust parsing: strip "DATABASE_URL=" prefix if it exists (common copy-paste error)
    let trimmed_url = if raw_url.trim().starts_with("DATABASE_URL=") {
        raw_url.trim().strip_prefix("DATABASE_URL=").unwrap().trim()
    } else {
        raw_url.trim()
    };

    // Redact password for logging
    let redacted_url = if let Some(at_pos) = trimmed_url.find('@') {
        if let Some(pass_start) = trimmed_url[..at_pos].find(':') {
             // Second colon usually starts password in postgres://user:pass@host
             if let Some(pass_at) = trimmed_url[(pass_start + 1)..at_pos].find(':') {
                let actual_pass_start = pass_start + 1 + pass_at;
                format!("{}***{}", &trimmed_url[..actual_pass_start+1], &trimmed_url[at_pos..])
             } else {
                trimmed_url.to_string()
             }
        } else {
            trimmed_url.to_string()
        }
    } else {
        trimmed_url.to_string()
    };
    println!("🔌 Using Connection String: {}", redacted_url);

    let options = PgConnectOptions::from_str(trimmed_url)
        .expect("Failed to parse DATABASE_URL")
        .statement_cache_capacity(0);

    println!("⏳ Connecting to database (Attempting with 60s timeout and retries)...");
    
    let mut retry_count = 0;
    let max_retries = 5;
    let pool = loop {
        match PgPoolOptions::new()
            .max_connections(10) // Respect Supabase pool_size limit (max 15)
            .min_connections(2)  // Keep some connections ready
            .acquire_timeout(std::time::Duration::from_secs(30)) 
            .idle_timeout(std::time::Duration::from_secs(600))
            .max_lifetime(std::time::Duration::from_secs(1800))
            .connect_with(options.clone())
            .await 
        {
            Ok(p) => break p,
            Err(e) => {
                retry_count += 1;
                println!("❌ Database connection attempt {} failed. Error: {:?}", retry_count, e);
                if retry_count >= max_retries {
                    panic!("❌ CRITICAL: Failed to connect to the database after {} attempts.", max_retries);
                }
                println!("⏳ Retrying in 5 seconds...");
                tokio::time::sleep(std::time::Duration::from_secs(5)).await;
            }
        }
    };

    println!("✅ Successfully connected to the database!");

    // Run migrations
    println!("🔧 Running migrations with extended timeout...");
    let _ = sqlx::query("SET statement_timeout = '300s'").execute(&pool).await; 
    
    match sqlx::migrate!("./migrations").run(&pool).await {
        Ok(_) => println!("✅ Migrations complete!"),
        Err(e) => {
            eprintln!("⚠️ Migration warning: {}. The app will try to continue.", e);
        }
    }
    
    // Reset timeout
    let _ = sqlx::query("SET statement_timeout = '30s'").execute(&pool).await;
    
    // FORCE FIX SCHEMA
    println!("🔧 Attempting to force-fix schema...");
    let _ = sqlx::query("DELETE FROM announcements WHERE title ILIKE '%Fixed Schema Test%' OR title ILIKE '%Local Test%'")
        .execute(&pool).await.map_err(|e| eprintln!("Delete test announcements failed: {:?}", e));
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS announcements (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            description TEXT NOT NULL,
            type VARCHAR(50) NOT NULL,
            audience TEXT[] NOT NULL,
            priority VARCHAR(50) NOT NULL,
            start_date TIMESTAMPTZ NOT NULL,
            end_date TIMESTAMPTZ NOT NULL,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
            attachment_url VARCHAR(255),
            creator_id UUID NOT NULL
        )
    ").execute(&pool).await.map_err(|e| eprintln!("Force Fix Announcements Failed: {:?}", e));

    let _ = sqlx::query("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A'")
        .execute(&pool)
        .await
        .map_err(|e| eprintln!("Force Fix Attendance Failed: {:?}", e));
        
    let _ = sqlx::query("ALTER TABLE users ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A'")
        .execute(&pool)
        .await
        .map_err(|e| eprintln!("Force Fix Users Failed: {:?}", e));
        
    let _ = sqlx::query("ALTER TABLE users ADD COLUMN IF NOT EXISTS title VARCHAR(100) DEFAULT NULL")
        .execute(&pool)
        .await
        .map_err(|e| eprintln!("Force Fix Users Title Failed: {:?}", e));
        
    // FORCE DATA REPAIR
    let _ = sqlx::query("UPDATE users SET section = 'Section A' WHERE section IS NULL")
        .execute(&pool)
        .await;
    let _ = sqlx::query("UPDATE users SET is_approved = true WHERE role = 'Student' AND is_approved = false")
        .execute(&pool)
        .await;
        
    // FORCE FIX SCHEMA - FACULTY SUBJECTS
    let _ = sqlx::query("ALTER TABLE faculty_subjects ADD COLUMN IF NOT EXISTS section VARCHAR(50) DEFAULT 'Section A'")
        .execute(&pool).await.err();
        
    let _ = sqlx::query("ALTER TABLE faculty_subjects DROP CONSTRAINT IF EXISTS faculty_subjects_pkey")
        .execute(&pool).await.err();

    let _ = sqlx::query("ALTER TABLE faculty_subjects ADD PRIMARY KEY (user_id, subject_id, section)")
        .execute(&pool).await.err();

    // FORCE FIX SCHEMA - LESSON PLAN PROGRESS
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS lesson_plan_progress (
            item_id TEXT REFERENCES lesson_plan_items(id) ON DELETE CASCADE,
            section VARCHAR(50),
            completed BOOLEAN DEFAULT FALSE,
            completed_date TIMESTAMPTZ,
            PRIMARY KEY (item_id, section)
        )
    ").execute(&pool).await.err();

    // DEPARTMENT TIMINGS TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS department_timings (
            branch TEXT PRIMARY KEY,
            start_hour INT NOT NULL DEFAULT 9,
            start_minute INT NOT NULL DEFAULT 0,
            class_duration INT NOT NULL DEFAULT 50,
            short_break_duration INT NOT NULL DEFAULT 10,
            lunch_duration INT NOT NULL DEFAULT 50,
            slot_config JSONB DEFAULT NULL
        )
    ").execute(&pool).await.err();

    // Migration: Add slot_config if not exists
    let _ = sqlx::query("ALTER TABLE department_timings ADD COLUMN IF NOT EXISTS slot_config JSONB DEFAULT NULL")
         .execute(&pool).await.err();
         
    // Migration: Add short_code if not exists
    let _ = sqlx::query("ALTER TABLE department_timings ADD COLUMN IF NOT EXISTS short_code VARCHAR(50) DEFAULT NULL")
         .execute(&pool).await.err();

    // SECTIONS TABLE (New)
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS sections (
            branch VARCHAR(255) NOT NULL,
            year VARCHAR(50) NOT NULL,
            section_name VARCHAR(50) NOT NULL,
            PRIMARY KEY (branch, year, section_name)
        )
    ").execute(&pool).await.err();
    
    // PARENT STUDENT TABLE (New)
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS parent_student (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            parent_id TEXT NOT NULL,
            student_id TEXT NOT NULL,
            relationship TEXT,
            UNIQUE(parent_id, student_id)
        )
    ").execute(&pool).await.err();

    // PARENT REQUESTS TABLE (New)
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS parent_requests (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            parent_id UUID NOT NULL REFERENCES users(id),
            student_id UUID NOT NULL REFERENCES users(id),
            request_type VARCHAR(50) NOT NULL,
            subject VARCHAR(255) NOT NULL,
            description TEXT NOT NULL,
            date_duration VARCHAR(100) NOT NULL,
            status VARCHAR(50) NOT NULL DEFAULT 'Pending',
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW(),
            assigned_to UUID REFERENCES users(id),
            voice_note TEXT
        )
    ").execute(&pool).await.map_err(|e| eprintln!("Force Fix Parent Requests Failed: {:?}", e));
    
    let _ = sqlx::query("ALTER TABLE parent_requests ADD COLUMN IF NOT EXISTS voice_note TEXT")
        .execute(&pool)
        .await
        .map_err(|e| eprintln!("Add voice_note to parent_requests failed: {:?}", e));
    
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_parent_requests_parent_id ON parent_requests(parent_id)").execute(&pool).await.err();
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_parent_requests_student_id ON parent_requests(student_id)").execute(&pool).await.err();

    // STUDENT MARKS TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS student_marks (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            student_id TEXT NOT NULL,
            semester TEXT NOT NULL,
            subject_name TEXT NOT NULL,
            marks INT DEFAULT NULL,
            UNIQUE(student_id, semester, subject_name)
        )
    ").execute(&pool).await.err();

    // Migration: Add credit if not exists
    let _ = sqlx::query("ALTER TABLE subjects ADD COLUMN IF NOT EXISTS credit INT DEFAULT 3")
         .execute(&pool).await.err();

    // TIMETABLE ENTRIES TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS timetable_entries (
            id UUID PRIMARY KEY,
            faculty_id TEXT NOT NULL,
            branch TEXT NOT NULL,
            year TEXT NOT NULL,
            section TEXT NOT NULL,
            day TEXT NOT NULL,
            period_index INT NOT NULL,
            subject TEXT NOT NULL,
            subject_code TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE(branch, year, section, day, period_index) 
        )
    ").execute(&pool).await.err();
    
    // COURSES TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS courses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL
        )
    ").execute(&pool).await.err();

    // Migration: Rename columns if they exist from older version
    let _ = sqlx::query("ALTER TABLE courses RENAME COLUMN course_id TO id").execute(&pool).await.err();
    let _ = sqlx::query("ALTER TABLE courses RENAME COLUMN course_name TO name").execute(&pool).await.err();

    // CLASS PERIOD STATUS TABLE (Smart Timetable Tracking)
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS class_period_status (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            branch TEXT NOT NULL,
            year TEXT NOT NULL,
            section TEXT NOT NULL,
            day TEXT NOT NULL,
            period_index INT NOT NULL,
            status_date DATE NOT NULL DEFAULT CURRENT_DATE,
            original_subject TEXT NOT NULL,
            original_faculty TEXT NOT NULL,
            actual_subject TEXT NOT NULL,
            actual_faculty TEXT NOT NULL,
            status TEXT NOT NULL, -- 'conducted', 'substitute', 'not_conducted'
            updated_by UUID REFERENCES users(id),
            updated_at TIMESTAMPTZ DEFAULT NOW(),
            UNIQUE(branch, year, section, day, period_index, status_date)
        )
    ").execute(&pool).await.err();

    // LESSON TOPICS TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS lesson_topics (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            subject_id TEXT NOT NULL,
            unit TEXT NOT NULL,
            topic_name TEXT NOT NULL
        )
    ").execute(&pool).await.err();

    // LESSON SCHEDULE TABLE
    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS lesson_schedule (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            subject_id TEXT NOT NULL,
            topic_id TEXT NOT NULL,
            schedule_date TIMESTAMPTZ,
            faculty_id TEXT,
            branch TEXT NOT NULL,
            year TEXT NOT NULL,
            semester TEXT NOT NULL,
            UNIQUE(subject_id, topic_id)
        )
    ").execute(&pool).await.err();
    
    let _ = sqlx::query("CREATE EXTENSION IF NOT EXISTS \"pgcrypto\"").execute(&pool).await;

    // Force migration from older schema versions if they exist
    let _ = sqlx::query("ALTER TABLE issues RENAME COLUMN user_id TO created_by").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues RENAME COLUMN subject TO title").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues RENAME COLUMN created_at TO created_date").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues RENAME COLUMN responded_by TO assigned_to").execute(&pool).await;

    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS issues (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            title VARCHAR(255) NOT NULL,
            description TEXT NOT NULL,
            category VARCHAR(100) NOT NULL DEFAULT 'General',
            priority VARCHAR(50) NOT NULL DEFAULT 'Medium',
            status VARCHAR(50) NOT NULL DEFAULT 'Open',
            created_by UUID NOT NULL REFERENCES users(id),
            user_role VARCHAR(50) NOT NULL DEFAULT 'Student',
            assigned_to UUID REFERENCES users(id),
            created_date TIMESTAMPTZ DEFAULT NOW()
        )
    ").execute(&pool).await.err();

    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS created_by UUID").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS user_role VARCHAR(50) DEFAULT 'Student'").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS category VARCHAR(100) DEFAULT 'General'").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS priority VARCHAR(50) DEFAULT 'Medium'").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS created_date TIMESTAMPTZ DEFAULT NOW()").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS title VARCHAR(255)").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS description TEXT").execute(&pool).await;
    let _ = sqlx::query("ALTER TABLE issues ADD COLUMN IF NOT EXISTS assigned_to UUID").execute(&pool).await;

    let _ = sqlx::query("
        CREATE TABLE IF NOT EXISTS issue_comments (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            issue_id UUID NOT NULL REFERENCES issues(id) ON DELETE CASCADE,
            comment TEXT NOT NULL,
            comment_by UUID NOT NULL REFERENCES users(id),
            comment_date TIMESTAMPTZ DEFAULT NOW()
        )
    ").execute(&pool).await.err();

    // Fallback: If `courses` table is empty, insert some default courses
    match pool.begin().await {
        Ok(mut tx) => {
            let courses_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM courses")
                .fetch_one(&mut *tx).await.unwrap_or(0);
            if courses_count == 0 {
                let _ = sqlx::query("INSERT INTO courses (id, name) VALUES ('C-23', 'Computer Engineering (C-23)'), ('C-26', 'Computer Engineering (C-26)')")
                    .execute(&mut *tx).await;
            }
            let _ = tx.commit().await;
        }
        Err(e) => eprintln!("Failed to start transaction for courses seed: {:?}", e),
    }
    
    match pool.begin().await {
        Ok(mut tx2) => {
            let topics_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM lesson_topics")
                .fetch_one(&mut *tx2).await.unwrap_or(0);
            if topics_count == 0 {
                let _ = sqlx::query("INSERT INTO lesson_topics (subject_id, unit, topic_name) VALUES ('1', 'Unit 1', 'Basics of Java'), ('1', 'Unit 1', 'Variables & Data Types')")
                    .execute(&mut *tx2).await;
            }
            let _ = tx2.commit().await;
        }
        Err(e) => eprintln!("Failed to start transaction for topics seed: {:?}", e),
    }

    // OPTIMIZATION INDEXES
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_attendance_lookup ON attendance(branch, year, session, date, section)")
        .execute(&pool).await.err();
        
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_users_lookup ON users(branch, year, section, role)")
        .execute(&pool).await.err();
        
    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_users_login_id ON users(login_id)")
        .execute(&pool).await.err();

    let _ = sqlx::query("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)")
        .execute(&pool).await.err();

    println!("🔧 Schema fix & Data distribution complete.");

    // Fix Branch Names (Run in background)
    let fix_pool = pool.clone();
    tokio::spawn(async move {
        fix_branch_names(&fix_pool).await;
    });

    pool
}

async fn fix_branch_names(pool: &Pool<Postgres>) {
    let updates = vec![
        ("CME", "Computer Engineering"),
        ("CM", "Computer Engineering"),
        ("Cme", "Computer Engineering"),
        ("CSE", "Computer Engineering"),
        ("Computer", "Computer Engineering"),
        ("ECE", "Electronics & Communication Engineering"),
        ("EC", "Electronics & Communication Engineering"),
        ("Ece", "Electronics & Communication Engineering"),
        ("EEE", "Electrical & Electronics Engineering"),
        ("EE", "Electrical & Electronics Engineering"),
        ("Eee", "Electrical & Electronics Engineering"),
        ("ME", "Mechanical Engineering"),
        ("MEC", "Mechanical Engineering"),
        ("MECH", "Mechanical Engineering"),
        ("Mech", "Mechanical Engineering"),
        ("Mechanical", "Mechanical Engineering"), 
        ("CE", "Civil Engineering"),
        ("CIV", "Civil Engineering"),
        ("CIVIL", "Civil Engineering"),
        ("Civil", "Civil Engineering"),
        ("BS & H", "General"),
        ("BS&H", "General"),
        ("BSH", "General"),
        ("Basic Science", "General"),
        ("General", "General"),
    ];

    let tables = vec!["users", "attendance", "notifications", "subjects", "faculty_subjects", "timetable_entries", "class_period_status"];

    for (short_code, full_name) in updates {
        for table in &tables {
            let query = format!("UPDATE {} SET branch = $1 WHERE branch = $2", table);
            
            let result = sqlx::query(&query)
                .bind(full_name)
                .bind(short_code)
                .execute(pool)
                .await;
                
            match result {
                Ok(r) => {
                    if r.rows_affected() > 0 {
                        println!("Updated {} rows in '{}': {} -> {}", r.rows_affected(), table, short_code, full_name);
                    }
                },
                Err(e) => eprintln!("Failed to update table '{}': {:?}", table, e),
            }
        }
    }
}
