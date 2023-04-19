import mysql from 'mysql';

export const handler = async (event, context) => {
  // create MySQL connection object
  const connection = mysql.createConnection({
    host: "arthurgooch-db-cluster.cluster-ckkhag7mpnl6.us-east-1.rds.amazonaws.com",
    user: "username",
    password: "password",
    database: "my_schema",
    charset: 'utf8mb4'
  });

  // List all tables in the database
  const tables = ["antarctica_weather", "Atlanta_Georgia_weather", "Browns_Mills_NJ_weather", "San_Fernando_Pampanga_Philippines_weather", "Savannah_Georgia_weather", "Seattle_Washington_weather"];

  // list to store results from all tables
  const results = [];

  // loop through tables and query for data
  for (const table of tables) {
    const query = `SELECT DISTINCT * FROM ${table} ORDER BY epoch_time DESC LIMIT 1`;
    const rows = await new Promise((resolve, reject) => {
      connection.query(query, (error, rows) => {
        if (error) {
          reject(error);
        } else {
          resolve(rows);
        }
      });
    });
    results.push(rows);
  }

  // close MySQL connection
  connection.end();

  return results;
};
