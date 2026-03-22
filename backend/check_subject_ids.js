const { Client } = require('pg');

async function checkSubjects() {
  const client = new Client({
    connectionString: "postgresql://postgres:Alwardas-Polytechnic%402025@db.eyvpvrfadrgnewxslxzo.supabase.co:5432/postgres?sslmode=require",
    ssl: { rejectUnauthorized: false }
  });
  await client.connect();
  const res = await client.query('SELECT id, name, branch FROM subjects LIMIT 10;');
  console.log('--- SUBJECTS TABLE ---');
  res.rows.forEach(r => console.log(`${r.id} | ${r.name} (${r.branch})`));
  
  const res2 = await client.query('SELECT id, subject_id, topic FROM lesson_plan_items LIMIT 5;');
  console.log('\n--- LPI TABLE ---');
  res2.rows.forEach(r => console.log(`${r.id} | SubjectID: ${r.subject_id} | Topic: ${r.topic}`));
  
  await client.end();
}

checkSubjects();
