const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT id, name FROM subjects WHERE branch = 'Computer Engineering' AND semester IN ('3rd Semester', 'Semester 3', 'Semester 3')");
        console.log("Subjects:", res.rows);
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
