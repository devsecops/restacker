# INTRODUCTION

The Control-Plane pattern/architecture is designed to mitigate and limit risk/exposure if an account were to be compromised.  
In DevSecOps, we call this **Blast Radius**.

## CONTROL PLANE
In a typical Control-Plane architecture, an account is designated as the Control Plane.  
It does not have any instances (e.g. EC2, RDS ...etc).  
The main purpose of this account is to maintain users and roles.

## TARGET PLANE
The target plane, or account, will host the instances, databases, and any other AWS services needed.  
The roles in this account trusts roles from the Control Plane/Account

## WORKFLOW
In a Control-Plane architecture, the workflow for performing operations on the Target Account will look like this:
 - Authenticate against the Control Account to obtain an AWS STS token.
 - Pass that STS token to the next Target Account to assume a specific role (e.g. Read-Only, Deploy-Admin, Incident-Response ...etc).
