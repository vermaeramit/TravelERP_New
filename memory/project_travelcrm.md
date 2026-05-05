---
name: TravelERP Project Context
description: Architecture and status of the Travel Company ERP built in travel_crm
type: project
---

Full-stack Travel Company ERP built from scratch in d:\Projects\travel_crm.

**Why:** User requested enterprise-level ERP for travel companies with multi-tenancy, Dapper, SQL Server, stored procedures only, and AdminLTE 4 theme.

**How to apply:** When asked to add features, extend modules, or fix bugs — follow the established architecture (SP-only, per-tenant DB, cookie auth claims).

## Solution Structure
- TravelERP.Web — ASP.NET Core 8 MVC, AdminLTE 4 theme, cookie auth
- TravelERP.Core — Domain entities, interfaces
- TravelERP.Infrastructure — Dapper repositories (SP only)
- TravelERP.Shared — DTOs, enums
- Database/Master — Master DB schema + SPs
- Database/Tenant — Tenant DB schema + SPs (provisioned per company at registration)

## Multi-Tenancy
- One master DB (TravelERP_Master): Companies + MasterUsers tables
- Per-company DB (TravelERP_{slug}): all business data
- Tenant resolved via cookie claims (CompanyId, DatabaseName)
- New company registration auto-provisions DB via TenantDbProvisioningService

## Modules Implemented
Dashboard, Customers, Bookings (auto-creates Invoice), Tour Packages, Suppliers, Finance (Invoices+Payments), HR (Employees+Leaves), Visa Applications, Reports, Company Setup, Auth (Login/Register)

## Key Rules
- ALL data access via stored procedures (CommandType.StoredProcedure)
- No raw SQL in repositories
- Password hashing: BCrypt.Net-Next
- Claims-based auth: CompanyId, DatabaseName, FullName, Currency, UserRole stored in cookie
