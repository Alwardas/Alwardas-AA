const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});

const faculty_user_id = '88280f27-6f77-4402-861c-8b2b9f69769a'; // I'll search for a faculty user id

client.connect()
    .then(async () => {
        // Find a faculty user
        const userRes = await client.query("SELECT id FROM users WHERE role = 'Faculty' LIMIT 1");
        if (userRes.rows.length === 0) {
            console.log("No faculty user found");
            client.end();
            return;
        }
        const userId = userRes.rows[0].id;
        console.log(`Testing for Faculty User ID: ${userId}`);

        try {
            const sql = `
                SELECT 
                    fs.subject_id as id, 
                    COALESCE(s.name, fs.subject_name) as name, 
                    COALESCE(s.branch, fs.branch) as branch, 
                    COALESCE(s.semester, 'Unknown') as semester, 
                    fs.status,
                    fs.subject_id,
                    fs.section,
                    0 as completion_percentage
                FROM faculty_subjects fs
                LEFT JOIN subjects s ON fs.subject_id = s.id::text
                WHERE fs.user_id = $1
                UNION ALL
                SELECT
                    cs.id::text as id,
                    cs.subject_name as name,
                    cs.branch,
                    cs.year as semester,
                    'APPROVED' as status,
                    COALESCE(cs.subject_code, cs.id::text) as subject_id,
                    cs.section,
                    0 as completion_percentage
                FROM course_subjects cs
                WHERE cs.created_by = $1::text
                ORDER BY subject_id ASC
            `;
            const res = await client.query(sql, [userId]);
            console.log(`Found ${res.rows.length} subjects.`);
            console.log("Sample row:", res.rows[0]);
        } catch (e) {
            console.error("Query Error:", e.message);
        }
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
