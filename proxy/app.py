import pymysql

# must install package pymysql

db_config = {
    "host": "ec2-18-212-70-235.compute-1.amazonaws.com",
    "user": "myapp",
    "password": "myapp",
    "database": "sakila",
}

# Establish a connection to the MySQL server
try:
    connection = pymysql.connect(**db_config)

    # Create a cursor object to interact with the database
    with connection.cursor() as cursor:
        # Example: Execute a SELECT query
        query = "SELECT count(*) FROM film"
        cursor.execute(query)

        # Fetch and print the results
        results = cursor.fetchall()
        for row in results:
            print(row)

except pymysql.Error as e:
    print(f"Error: {e}")

finally:
    # Close the connection
    if 'connection' in locals() and connection.open:
        connection.close()
        print("MySQL connection closed.")