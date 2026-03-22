const { Client } = require('pg');

async function check() {
    const client = new Client({
        connectionString: 'postgresql://postgres:Alwardas-Polytechnic%402025@db.eyvpvrfadrgnewxslxzo.supabase.co:5432/postgres?sslmode=require'
    });
    await client.connect();
    
    // Check data
    const res = await client.query("SELECT id, type, sno, topic, text, order_index FROM lesson_plan_items WHERE subject_id = '1' ORDER BY order_index ASC");
    console.log(JSON.stringify(res.rows, null, 2));
    
    await client.end();
}

check().catch(console.error);
