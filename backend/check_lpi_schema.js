const { Client } = require('pg');

async function check() {
    const client = new Client({
        connectionString: 'postgresql://postgres:Alwardas-Polytechnic%402025@db.eyvpvrfadrgnewxslxzo.supabase.co:5432/postgres?sslmode=require'
    });
    await client.connect();
    
    // Check data
    const res = await client.query("SELECT * FROM lesson_plan_items LIMIT 20");
    console.log(JSON.stringify(res.rows, null, 2));
    
    await client.end();
}

check().catch(console.error);
