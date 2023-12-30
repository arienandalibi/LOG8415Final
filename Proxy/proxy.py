# This is pseudocode and doesn't execute
# However, if I were to make a proxy using python, it would have this format

# The app would use flask
# The hostnames of the instances would be passed by terraform's templatefile
# manager_dns = ${managerPrivateDNS}
# worker1_dns = ${worker1PrivateDNS}
# worker2_dns = ${worker2PrivateDNS}
# worker3_dns = ${worker3PrivateDNS}


"""
Creates and maintains 4 SSH Tunnel port forwards, they will be used to route requests to
These will be stored in global variables to be accessed by the application
This code would execute during the application's startup.
Args:
    None
Returns:
    The 4 SSH Tunnels in 4 different variables
"""
def establish_tunnels():
    return None


"""
Pings the 3 worker nodes and returns an index based on which has the fastest responsiveness.
1-3 correspond to workers 1-3, and 0 isn't used because it corresponds to the manager.
Args:
    None
Returns:
    An int corresponding to the fastest worker node
"""
def ping_workers():
    return None

"""
@approute for GET method on endpoint /directhit, The GET request must contain the query to be executed.
This function extracts the query and uses the already established SSH tunnel to send the extracted query to manager_dns
This would be accomplished using a popular MySQL package for python such as mysql.connector or pymysql
A connection would have to be created and then broken once the query is done executing
Args:
    None, but the GET request comes with the query
Returns:
    Response from the MySQL database in a nice format (custom or JSON)
"""
#@approute GET method
def directhit():
    return None

"""
@approute for GET method on endpoint /random, The GET request must contain the query to be executed.
This function chooses a random number between 1 and 3, extracts the query ,
and uses the appropriate and already established SSH tunnel to send the extracted query to the randomly chosen worker node
This would be accomplished using a popular MySQL package for python such as mysql.connector or pymysql
A connection would have to be created and then broken once the query is done executing
Args:
    None, but the GET request comes with the query
Returns:
    Response from the MySQL database in a nice format (custom or JSON)
"""
#@approute GET method
def random():
    return None

"""
@approute for GET method on endpoint /customized, The GET request must contain the query to be executed.
This function calls ping_workers() to get the fastest worker node, extracts the query,
and uses the appropriate and already established SSH tunnel to send the extracted query to the chosen worker node (fastest)
This would be accomplished using a popular MySQL package for python such as mysql.connector or pymysql
A connection would have to be created and then broken once the query is done executing
Args:
    None, but the GET request comes with the query
Returns:
    Response from the MySQL database in a nice format (custom or JSON)
"""
#@approute GET method
def customized():
    return None

"""
Main function to run the flask app
Args:
    None
Returns:
    None
"""
if __name__ == "__main__":


# This file would get passed to the user_data script as input to sudo tee into a file using terraform templatefile,
# install the proper requirements, and execute this app