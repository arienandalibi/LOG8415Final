import socket
import mysql.connector

# get manager's dns
with open("/home/ubuntu/manager_dns.log", 'r') as file:
    manager_dns = file.read()
manager_connection = mysql.connector.connect(host=manager_dns, user='myapp', password='myapp', database='sakila')
worker1_connection = mysql.connector.connect(host='${worker1privateDNS}', user='myapp', password='myapp', database='sakila')
worker2_connection = mysql.connector.connect(host='${worker1privateDNS}', user='myapp', password='myapp', database='sakila')
worker3_connection = mysql.connector.connect(host='${worker1privateDNS}', user='myapp', password='myapp', database='sakila')

def start_server(port, pattern):
    # Create a socket object
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # Bind the socket to a specific address and port
    server_socket.bind(('localhost', port))

    # Listen for incoming connections (max 5 connections in the queue)
    server_socket.listen(5)
    print(f"Server listening on port {port}")

    while True:
        # Wait for a connection from a client
        client_socket, client_address = server_socket.accept()
        print(f"Connection established with {client_address}")

        # Receive data from the client
        data = client_socket.recv(1024).decode('utf-8')
        print(f"Received data: {data}")

        # Send query to MySQL client
        if pattern == "ping":
            send_query_ping(data)

        # Close the connection with the client
        client_socket.close()
        print(f"Connection with {client_address} closed")

def send_query_ping(query):


if __name__ == "__main__":
    # Start the server
    start_server(3306, "ping", manager_connection, worker1_connection, worker2_connection, worker3_connection)
