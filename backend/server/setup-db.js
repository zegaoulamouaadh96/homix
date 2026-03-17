const { Pool } = require('pg');

const passwordsToTry = ['', 'postgres', 'admin', 'password', 'root'];

async function setupDatabase() {
  let adminPool;
  let adminClient;
  let connected = false;

  for (const password of passwordsToTry) {
    try {
      console.log(`Trying postgres password: "${password || '(empty)'}"`);
      adminPool = new Pool({
        user: 'postgres',
        password: password,
        host: 'localhost',
        port: 5432,
        database: 'postgres',
        connect_timeout: 5000
      });
      
      adminClient = await adminPool.connect();
      console.log('✓ Connected to PostgreSQL\n');
      connected = true;
      break;
    } catch (error) {
      if (adminPool) {
        try { await adminPool.end(); } catch (e) {}
      }
    }
  }

  if (!connected) {
    console.error('✗ Failed to connect with any password');
    console.log('\nTry setting the password and running again:');
    console.log('$env:PGPASSWORD = "your_password"; node setup-db.js');
    process.exit(1);
  }

  try {
    const userCheck = await adminClient.query(
      "SELECT 1 FROM pg_user WHERE usename = 'app'"
    );

    if (userCheck.rows.length === 0) {
      console.log('Creating user "app"...');
      await adminClient.query("CREATE USER app WITH PASSWORD 'app123'");
      console.log('✓ User "app" created');
    } else {
      console.log('✓ User "app" already exists');
    }

    const dbCheck = await adminClient.query(
      "SELECT 1 FROM pg_database WHERE datname = 'smarthome'"
    );

    if (dbCheck.rows.length === 0) {
      console.log('Creating database "smarthome"...');
      await adminClient.query('CREATE DATABASE smarthome OWNER app');
      console.log('✓ Database "smarthome" created');
    } else {
      console.log('✓ Database "smarthome" already exists');
    }

    console.log('Granting privileges...');
    await adminClient.query('GRANT ALL PRIVILEGES ON DATABASE smarthome TO app');
    console.log('✓ Privileges granted');

    adminClient.release();
    await adminPool.end();

    console.log('\n✅ Database setup completed!');
    console.log('\nStart the API with: npm start\n');
    process.exit(0);
  } catch (error) {
    console.error('✗ Error:', error.message);
    if (adminClient) adminClient.release();
    if (adminPool) await adminPool.end();
    process.exit(1);
  }
}

setupDatabase();
