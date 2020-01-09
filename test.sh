#!/usr/bin/env bash

	case "aa" in
		a) false;;
		*) true;;
	esac

	echo $?
