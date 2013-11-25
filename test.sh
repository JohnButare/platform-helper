#!/bin/bash

a()
{
	result=$(date "+%Y_%m_%d %H_%M_%S" -d @1385329140.000000000)
}

b()
{
	date "+%Y_%m_%d %H_%M_%S" -d @1385329140.000000000
}

time a
time result="$(b)"