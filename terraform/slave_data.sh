#!/bin/bash

export worker1hostID=$(aws_instance.worker1.host_id)
export worker1hostID2=${aws_instance.worker1.host_id}

export worker1hostARN = $(aws_instance.worker1.host_resource_group_arn)
export worker1hostARN2 = ${aws_instance.worker1.host_resource_group_arn}