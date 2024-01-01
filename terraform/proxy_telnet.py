import socket
import subprocess
import random
import mysql.connector

# Creates and maintains 4 MySQL connections, they will be used to route requests to
with open("/home/ubuntu/manager_dns.log", 'r') as file:
    manager_dns = file.read()
    manager_dns = manager_dns.rstrip('\n')
manager_connection = mysql.connector.connect(host=manager_dns, user='myapp', password='myapp', database='sakila')
worker1_connection = mysql.connector.connect(host='127.0.0.1', port=3307, user='myapp', password='myapp', database='sakila')
worker2_connection = mysql.connector.connect(host='127.0.0.1', port=3308, user='myapp', password='myapp', database='sakila')
worker3_connection = mysql.connector.connect(host='127.0.0.1', port=3309, user='myapp', password='myapp', database='sakila')


def start_server(port, pattern):
    """
    Starts the server and listens for connections on port 3306.
    If a connection is made, it listens for the next query to send it to the MySQL database
    Once the response is received it forwards that response to the client
    Args:
        :param port: The port to listen for connections on
        :param pattern: The pattern we will use to route requests, can be "ping", "random", or "direct"
    Returns:
        None
    """
    # Create a socket object
    server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # Bind the socket to a specific address and port
    server_socket.bind(('localhost', port))

    # Listen for incoming connections (max 5 connections in the queue)
    server_socket.listen(1)
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
            result = send_query_ping(data)
        elif pattern == "random":
            result = send_query_random(data)
        elif pattern == "direct":
            result = send_query(data, 0)
        else:
            result = "Wrong pattern, correct usage is \"ping\", \"random\", or \"direct\"."

        client_socket.send(result.encode('utf-8'))

        # Close the connection with the client
        client_socket.close()
        print(f"Connection with {client_address} closed")


def send_query_random(query):
    """
    Selects a random server to send the query to
    Args:
        query (str): The query to send to the MySQL database
    Returns:
        str: A string containing the response from the server
    """
    selected = random.randint(0, 3)
    return send_query(query, selected)


def send_query_ping(query):
    """
    Pings the servers to find the server with the lowest ping, and sends the query to that server
    Args:
        query (str): The query to send to the MySQL database
    Returns:
        str: A string containing the response from the server
    """
    minPing = 21474836
    fastest = -1
    i = 0
    for server in [manager_dns, "${worker1privateDNS}", "${worker2privateDNS}", "${worker3privateDNS}"]:
        command = f"ping -c 1 {server} | grep \"time=\" | awk -F'=' '{{print $4}}' | cut -d' ' -f1"
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, text=True, check=True)
        print(f"result is: {result}")
        ping = float(result.stdout.strip())
        print(f"ping is: {ping}")
        if ping < minPing:
            minPing = ping
            fastest = i
        i += 1

    return send_query(query, fastest)


def send_query(query, server_int):
    """
    Sends the query to the selected server and returns a string containing the response from the server
    Args:
        query (str): The query to send to the MySQL database
        server_int (int): The integer corresponding to the server (0: master, 1: worker 1, 2: worker 2, 3: worker 3)
    Returns:
        str: A string containing the response from the server
    """
    cursor = None
    if server_int == 0:
        cursor = manager_connection.cursor()
    elif server_int == 1:
        cursor = worker1_connection.cursor()
    elif server_int == 2:
        cursor = worker2_connection.cursor()
    elif server_int == 3:
        cursor = worker3_connection.cursor()
    else:
        print("Some error")

    cursor.execute(query)

    rows = cursor.fetchall()
    output = '\n'.join(map(str, rows))
    cursor.close()
    return output


if __name__ == "__main__":
    # Start the server
    start_server(3306, "ping")
