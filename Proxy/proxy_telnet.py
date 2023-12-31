import socket

def start_server(port):
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

        # Close the connection with the client
        client_socket.close()
        print(f"Connection with {client_address} closed")

if __name__ == "__main__":
    # Start the server
    start_server(3306)
