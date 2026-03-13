const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'subjects'");
        console.log("Subjects Columns:", res.rows.map(r => r.column_name));
        
        const res2 = await client.query("SELECT column_name FROM information_schema.columns WHERE table_name = 'course_subjects'");
        console.log("Course Subjects Columns:", res2.rows.map(r => r.column_name));
        
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
