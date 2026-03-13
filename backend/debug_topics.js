const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const branch = 'Computer Engineering';
        const sem = '3rd Semester';
        const res = await client.query(`
            SELECT id, name FROM subjects WHERE branch = $1 AND semester = $2
        `, [branch, sem]);
        console.log("Subjects:", res.rows);
        
        for (let s of res.rows) {
            const lpCount = await client.query("SELECT COUNT(*) FROM lesson_plan_items WHERE subject_id = $1", [s.id]);
            console.log(`Subject: ${s.id} (${s.name}), LP Count: ${lpCount.rows[0].count}`);
        }
        
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
