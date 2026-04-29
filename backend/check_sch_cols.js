const { Client } = require('pg');
const client = new Client({
    connectionString: 'postgresql://postgres.eyvpvrfadrgnewxslxzo:Alwardas-Polytechnic%402025@aws-1-ap-south-1.pooler.supabase.com:5432/postgres',
    ssl: {
        rejectUnauthorized: false
    }
});
client.connect()
    .then(async () => {
        const res = await client.query("SELECT * FROM lesson_schedule LIMIT 1");
        if (res.rows.length > 0) {
            console.log(Object.keys(res.rows[0]));
        } else {
            console.log("No schedules yet.");
        }
        client.end();
    })
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
