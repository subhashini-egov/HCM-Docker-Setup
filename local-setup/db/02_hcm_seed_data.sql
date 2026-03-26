-- ============================================================================
-- 02_hcm_seed_data.sql
-- HCM Seed Data: Replicates the data created by the HCM Seed Postman collection
-- This script is idempotent (uses ON CONFLICT DO NOTHING where possible).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Pre-requisite: The 01_seed_data_dump.sql (COPY format) loads boundary,
-- MDMS, product, and product_variant data. This script adds users, workflows,
-- projects, facilities, project-staff, project-resources, project-facilities.
-- ---------------------------------------------------------------------------

-- The seed dump was exported with owner 'testhealth'. If the DB role does not
-- exist, the COPY statements in 01 may fail. Create the role if missing.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'testhealth') THEN
    CREATE ROLE testhealth WITH LOGIN;
  END IF;
END
$$;

-- Also ensure seq_eg_user sequence exists (user-service creates it via flyway,
-- but we need it here for direct inserts).
CREATE SEQUENCE IF NOT EXISTS public.seq_eg_user START WITH 100 INCREMENT BY 1;

-- ============================================================================
-- 1. USERS (eg_user + eg_userrole_v1)
-- ============================================================================
-- Fixed UUIDs for reproducibility. Password hash for eGov@1234.
-- The bcrypt hash below corresponds to eGov@1234 (taken from known DIGIT deployments).

-- Fixed user IDs (bigint) - start at 100 to avoid conflicts with platform default users
-- Also advance the sequence past our IDs.
SELECT setval('public.seq_eg_user', GREATEST(
  COALESCE((SELECT last_value FROM public.seq_eg_user), 0), 106
));

-- User UUIDs (fixed for reproducibility)
-- SU-0001:  a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d
-- DS-0001:  b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e
-- WM-0001:  c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f
-- HFW-0001: d4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f80
-- D-0001:   e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8091
-- HR-PGR-0001: f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8091a2

INSERT INTO public.eg_user (
  id, uuid, username, password, pwdexpirydate, mobilenumber,
  emailid, createddate, lastmodifieddate, createdby, lastmodifiedby,
  active, name, gender, type, version, tenantid, accountlocked
) VALUES
-- Superadmin (SU-0001)
(100, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d',
 'SU-0001', '$2a$10$nLHDKXt3OFwLZJPtNC5YkuVTVMd3sAufKXq2nlzAOyjzYdlPS.mHC',
 NOW() + INTERVAL '90 days', '5689999982', NULL,
 NOW(), NOW(), NULL, NULL, true, 'Superuser', 2, 'EMPLOYEE', 0, 'mz', false),

-- District Supervisor (DS-0001)
(101, 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e',
 'DS-0001', '$2a$10$nLHDKXt3OFwLZJPtNC5YkuVTVMd3sAufKXq2nlzAOyjzYdlPS.mHC',
 NOW() + INTERVAL '90 days', '5689999983', NULL,
 NOW(), NOW(), NULL, NULL, true, 'supervisor', 2, 'EMPLOYEE', 0, 'mz', false),

-- Warehouse Manager (WM-0001)
(102, 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f',
 'WM-0001', '$2a$10$nLHDKXt3OFwLZJPtNC5YkuVTVMd3sAufKXq2nlzAOyjzYdlPS.mHC',
 NOW() + INTERVAL '90 days', '5689989982', NULL,
 NOW(), NOW(), NULL, NULL, true, 'Warehouse manager', 2, 'EMPLOYEE', 0, 'mz', false),

-- HF Referral (HFW-0001)
(103, 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f80',
 'HFW-0001', '$2a$10$nLHDKXt3OFwLZJPtNC5YkuVTVMd3sAufKXq2nlzAOyjzYdlPS.mHC',
 NOW() + INTERVAL '90 days', '5689982982', NULL,
 NOW(), NOW(), NULL, NULL, true, 'HF Referral', 2, 'EMPLOYEE', 0, 'mz', false),

-- Distributor (D-0001)
(104, 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8091',
 'D-0001', '$2a$10$nLHDKXt3OFwLZJPtNC5YkuVTVMd3sAufKXq2nlzAOyjzYdlPS.mHC',
 NOW() + INTERVAL '90 days', '5689982983', NULL,
 NOW(), NOW(), NULL, NULL, true, 'Distributor', 2, 'EMPLOYEE', 0, 'mz', false),

-- HRMS PGR Admin (HR-PGR-0001)
(105, 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8091a2',
 'HR-PGR-0001', '$2a$10$nLHDKXt3OFwLZJPtNC5YkuVTVMd3sAufKXq2nlzAOyjzYdlPS.mHC',
 NOW() + INTERVAL '90 days', '5689999984', NULL,
 NOW(), NOW(), NULL, NULL, true, 'HRMS PGR Admin', 2, 'EMPLOYEE', 0, 'mz', false)

ON CONFLICT (id) DO NOTHING;

-- Also create user address records (the user-service expects these)
CREATE TABLE IF NOT EXISTS public.eg_user_address (
  id bigint,
  version bigint DEFAULT 0,
  createddate timestamp,
  lastmodifieddate timestamp,
  createdby bigint,
  lastmodifiedby bigint,
  type varchar(50),
  address varchar(300),
  city varchar(300),
  pincode varchar(10),
  userid bigint,
  tenantid varchar(256)
);

INSERT INTO public.eg_user_address (id, version, createddate, lastmodifieddate, createdby, lastmodifiedby, type, userid, tenantid)
SELECT v.id, 0, NOW(), NOW(), v.userid, NULL, v.type, v.userid, 'mz'
FROM (VALUES
  (200, 100, 'CORRESPONDENCE'), (201, 100, 'PERMANENT'),
  (202, 101, 'CORRESPONDENCE'), (203, 101, 'PERMANENT'),
  (204, 102, 'CORRESPONDENCE'), (205, 102, 'PERMANENT'),
  (206, 103, 'CORRESPONDENCE'), (207, 103, 'PERMANENT'),
  (208, 104, 'CORRESPONDENCE'), (209, 104, 'PERMANENT'),
  (210, 105, 'CORRESPONDENCE'), (211, 105, 'PERMANENT')
) AS v(id, userid, type)
WHERE NOT EXISTS (SELECT 1 FROM public.eg_user_address WHERE id = v.id);

-- ---------------------------------------------------------------------------
-- User Roles (eg_userrole_v1)
-- Pattern: role_code, role_tenantid, user_id (bigint), user_tenantid, lastmodifieddate
-- ---------------------------------------------------------------------------

-- Ensure the table exists (flyway should have created it)
CREATE TABLE IF NOT EXISTS public.eg_userrole_v1 (
  role_code varchar(64),
  role_tenantid varchar(256),
  user_id bigint,
  user_tenantid varchar(256),
  lastmodifieddate timestamp
);

-- Superadmin roles (SU-0001, id=100)
INSERT INTO public.eg_userrole_v1 (role_code, role_tenantid, user_id, user_tenantid, lastmodifieddate)
SELECT v.role_code, 'mz', 100, 'mz', NOW()
FROM (VALUES
  ('HRMS_ADMIN'), ('HELPDESK_USER'), ('REGISTRAR'), ('SYSTEM_ADMINISTRATOR'),
  ('HEALTH_FACILITY_WORKER'), ('DISTRIBUTOR'), ('WAREHOUSE_MANAGER'),
  ('L2_SUPPORT'), ('PGR-ADMIN')
) AS v(role_code)
WHERE NOT EXISTS (
  SELECT 1 FROM public.eg_userrole_v1
  WHERE role_code = v.role_code AND user_id = 100 AND role_tenantid = 'mz'
);

-- District Supervisor roles (DS-0001, id=101)
INSERT INTO public.eg_userrole_v1 (role_code, role_tenantid, user_id, user_tenantid, lastmodifieddate)
SELECT v.role_code, 'mz', 101, 'mz', NOW()
FROM (VALUES
  ('FIELD_SUPERVISOR'), ('NATIONAL_SUPERVISOR'), ('DISTRICT_SUPERVISOR'), ('PROVINCIAL_SUPERVISOR')
) AS v(role_code)
WHERE NOT EXISTS (
  SELECT 1 FROM public.eg_userrole_v1
  WHERE role_code = v.role_code AND user_id = 101 AND role_tenantid = 'mz'
);

-- Warehouse Manager roles (WM-0001, id=102)
INSERT INTO public.eg_userrole_v1 (role_code, role_tenantid, user_id, user_tenantid, lastmodifieddate)
SELECT v.role_code, 'mz', 102, 'mz', NOW()
FROM (VALUES ('WAREHOUSE_MANAGER')) AS v(role_code)
WHERE NOT EXISTS (
  SELECT 1 FROM public.eg_userrole_v1
  WHERE role_code = v.role_code AND user_id = 102 AND role_tenantid = 'mz'
);

-- HF Referral roles (HFW-0001, id=103)
INSERT INTO public.eg_userrole_v1 (role_code, role_tenantid, user_id, user_tenantid, lastmodifieddate)
SELECT v.role_code, 'mz', 103, 'mz', NOW()
FROM (VALUES ('HEALTH_FACILITY_WORKER')) AS v(role_code)
WHERE NOT EXISTS (
  SELECT 1 FROM public.eg_userrole_v1
  WHERE role_code = v.role_code AND user_id = 103 AND role_tenantid = 'mz'
);

-- Distributor roles (D-0001, id=104)
INSERT INTO public.eg_userrole_v1 (role_code, role_tenantid, user_id, user_tenantid, lastmodifieddate)
SELECT v.role_code, 'mz', 104, 'mz', NOW()
FROM (VALUES ('DISTRIBUTOR')) AS v(role_code)
WHERE NOT EXISTS (
  SELECT 1 FROM public.eg_userrole_v1
  WHERE role_code = v.role_code AND user_id = 104 AND role_tenantid = 'mz'
);

-- HRMS PGR Admin roles (HR-PGR-0001, id=105)
INSERT INTO public.eg_userrole_v1 (role_code, role_tenantid, user_id, user_tenantid, lastmodifieddate)
SELECT v.role_code, 'mz', 105, 'mz', NOW()
FROM (VALUES
  ('PGR-ADMIN'), ('NATIONAL_SUPERVISOR'), ('HRMS_ADMIN'), ('HELPDESK_USER')
) AS v(role_code)
WHERE NOT EXISTS (
  SELECT 1 FROM public.eg_userrole_v1
  WHERE role_code = v.role_code AND user_id = 105 AND role_tenantid = 'mz'
);

-- ============================================================================
-- 2. WORKFLOW BUSINESS SERVICES
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 2a. PGR Workflow
-- ---------------------------------------------------------------------------
INSERT INTO public.eg_wf_businessservice_v2 (
  uuid, businessservice, business, tenantid, businessservicesla,
  createdby, createdtime, lastmodifiedby, lastmodifiedtime
) VALUES (
  'aabbccdd-1111-4aaa-bbbb-ccccddddeeee',
  'PGR', 'pgr-services', 'mz', 432000000,
  'system', 1700000000000, 'system', 1700000000000
) ON CONFLICT (uuid) DO NOTHING;

-- PGR States
INSERT INTO public.eg_wf_state_v2 (
  uuid, tenantid, businessserviceid, state, applicationstatus, sla,
  docuploadrequired, isstartstate, isterminatestate,
  createdby, createdtime, lastmodifiedby, lastmodifiedtime, seq, isstateupdatable
) VALUES
-- Start state (null)
('aa000001-0001-4000-a001-000000000001', 'mz', 'aabbccdd-1111-4aaa-bbbb-ccccddddeeee',
 NULL, NULL, NULL, false, true, false,
 'system', 1700000000000, 'system', 1700000000000, 1, true),
-- PENDINGFORASSIGNMENT
('aa000001-0001-4000-a001-000000000002', 'mz', 'aabbccdd-1111-4aaa-bbbb-ccccddddeeee',
 'PENDINGFORASSIGNMENT', 'PENDINGFORASSIGNMENT', NULL, false, false, false,
 'system', 1700000000000, 'system', 1700000000000, 2, false),
-- PENDINGATLME
('aa000001-0001-4000-a001-000000000003', 'mz', 'aabbccdd-1111-4aaa-bbbb-ccccddddeeee',
 'PENDINGATLME', 'PENDINGATLME', 300000, false, false, false,
 'system', 1700000000000, 'system', 1700000000000, 3, false),
-- RESOLVED
('aa000001-0001-4000-a001-000000000004', 'mz', 'aabbccdd-1111-4aaa-bbbb-ccccddddeeee',
 'RESOLVED', 'RESOLVED', 300000, false, false, true,
 'system', 1700000000000, 'system', 1700000000000, 4, false),
-- REJECTED
('aa000001-0001-4000-a001-000000000005', 'mz', 'aabbccdd-1111-4aaa-bbbb-ccccddddeeee',
 'REJECTED', 'REJECTED', 300000, false, false, true,
 'system', 1700000000000, 'system', 1700000000000, 5, false),
-- CLOSEDAFTERRESOLUTION
('aa000001-0001-4000-a001-000000000006', 'mz', 'aabbccdd-1111-4aaa-bbbb-ccccddddeeee',
 'CLOSEDAFTERRESOLUTION', 'CLOSEDAFTERRESOLUTION', NULL, false, false, true,
 'system', 1700000000000, 'system', 1700000000000, 6, false),
-- CLOSEDAFTERREJECTION
('aa000001-0001-4000-a001-000000000007', 'mz', 'aabbccdd-1111-4aaa-bbbb-ccccddddeeee',
 'CLOSEDAFTERREJECTION', 'CLOSEDAFTERREJECTION', NULL, false, false, true,
 'system', 1700000000000, 'system', 1700000000000, 7, false)
ON CONFLICT (uuid) DO NOTHING;

-- PGR Actions
INSERT INTO public.eg_wf_action_v2 (
  uuid, tenantid, currentstate, action, nextstate, roles, active,
  createdby, createdtime, lastmodifiedby, lastmodifiedtime
) VALUES
-- START -> PENDINGFORASSIGNMENT (APPLY)
('bb000001-0001-4000-b001-000000000001', 'mz',
 'aa000001-0001-4000-a001-000000000001', 'APPLY',
 'aa000001-0001-4000-a001-000000000002',
 'CITIZEN,REGISTRAR', true,
 'system', 1700000000000, 'system', 1700000000000),
-- PENDINGFORASSIGNMENT -> PENDINGATLME (ASSIGN)
('bb000001-0001-4000-b001-000000000002', 'mz',
 'aa000001-0001-4000-a001-000000000002', 'ASSIGN',
 'aa000001-0001-4000-a001-000000000003',
 'REGISTRAR,HELPDESK_USER,SYSTEM_ADMINISTRATOR,PGR-ADMIN', true,
 'system', 1700000000000, 'system', 1700000000000),
-- PENDINGFORASSIGNMENT -> REJECTED (REJECT)
('bb000001-0001-4000-b001-000000000003', 'mz',
 'aa000001-0001-4000-a001-000000000002', 'REJECT',
 'aa000001-0001-4000-a001-000000000005',
 'REGISTRAR,HELPDESK_USER,SYSTEM_ADMINISTRATOR,PGR-ADMIN', true,
 'system', 1700000000000, 'system', 1700000000000),
-- PENDINGATLME -> RESOLVED (RESOLVE)
('bb000001-0001-4000-b001-000000000004', 'mz',
 'aa000001-0001-4000-a001-000000000003', 'RESOLVE',
 'aa000001-0001-4000-a001-000000000004',
 'REGISTRAR,HELPDESK_USER,SYSTEM_ADMINISTRATOR,PGR-ADMIN', true,
 'system', 1700000000000, 'system', 1700000000000),
-- PENDINGATLME -> PENDINGFORASSIGNMENT (REASSIGN)
('bb000001-0001-4000-b001-000000000005', 'mz',
 'aa000001-0001-4000-a001-000000000003', 'REASSIGN',
 'aa000001-0001-4000-a001-000000000002',
 'REGISTRAR,HELPDESK_USER,SYSTEM_ADMINISTRATOR,PGR-ADMIN', true,
 'system', 1700000000000, 'system', 1700000000000),
-- RESOLVED -> CLOSEDAFTERRESOLUTION (RATE/CLOSECOMPLAINT)
('bb000001-0001-4000-b001-000000000006', 'mz',
 'aa000001-0001-4000-a001-000000000004', 'CLOSECOMPLAINT',
 'aa000001-0001-4000-a001-000000000006',
 'CITIZEN,REGISTRAR,HELPDESK_USER,SYSTEM_ADMINISTRATOR,PGR-ADMIN', true,
 'system', 1700000000000, 'system', 1700000000000),
-- RESOLVED -> PENDINGFORASSIGNMENT (REOPEN)
('bb000001-0001-4000-b001-000000000007', 'mz',
 'aa000001-0001-4000-a001-000000000004', 'REOPEN',
 'aa000001-0001-4000-a001-000000000002',
 'CITIZEN,REGISTRAR,HELPDESK_USER,SYSTEM_ADMINISTRATOR,PGR-ADMIN', true,
 'system', 1700000000000, 'system', 1700000000000),
-- REJECTED -> CLOSEDAFTERREJECTION (CLOSECOMPLAINT)
('bb000001-0001-4000-b001-000000000008', 'mz',
 'aa000001-0001-4000-a001-000000000005', 'CLOSECOMPLAINT',
 'aa000001-0001-4000-a001-000000000007',
 'CITIZEN,REGISTRAR,HELPDESK_USER,SYSTEM_ADMINISTRATOR,PGR-ADMIN', true,
 'system', 1700000000000, 'system', 1700000000000),
-- REJECTED -> PENDINGFORASSIGNMENT (REOPEN)
('bb000001-0001-4000-b001-000000000009', 'mz',
 'aa000001-0001-4000-a001-000000000005', 'REOPEN',
 'aa000001-0001-4000-a001-000000000002',
 'CITIZEN,REGISTRAR,HELPDESK_USER,SYSTEM_ADMINISTRATOR,PGR-ADMIN', true,
 'system', 1700000000000, 'system', 1700000000000)
ON CONFLICT (uuid) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2b. HCMMUSTERROLL Workflow
-- ---------------------------------------------------------------------------
INSERT INTO public.eg_wf_businessservice_v2 (
  uuid, businessservice, business, tenantid, businessservicesla,
  createdby, createdtime, lastmodifiedby, lastmodifiedtime
) VALUES (
  'aabbccdd-2222-4aaa-bbbb-ccccddddeeee',
  'HCMMUSTERROLL', 'health-muster-roll', 'mz', 432000000,
  'system', 1700000000000, 'system', 1700000000000
) ON CONFLICT (uuid) DO NOTHING;

-- HCMMUSTERROLL States
INSERT INTO public.eg_wf_state_v2 (
  uuid, tenantid, businessserviceid, state, applicationstatus, sla,
  docuploadrequired, isstartstate, isterminatestate,
  createdby, createdtime, lastmodifiedby, lastmodifiedtime, seq, isstateupdatable
) VALUES
-- Start state (null)
('aa000002-0001-4000-a002-000000000001', 'mz', 'aabbccdd-2222-4aaa-bbbb-ccccddddeeee',
 NULL, NULL, NULL, false, true, false,
 'system', 1700000000000, 'system', 1700000000000, 1, true),
-- APPROVAL_PENDING
('aa000002-0001-4000-a002-000000000002', 'mz', 'aabbccdd-2222-4aaa-bbbb-ccccddddeeee',
 'APPROVAL_PENDING', 'APPROVAL_PENDING', NULL, false, false, false,
 'system', 1700000000000, 'system', 1700000000000, 2, false),
-- APPROVED
('aa000002-0001-4000-a002-000000000003', 'mz', 'aabbccdd-2222-4aaa-bbbb-ccccddddeeee',
 'APPROVED', 'APPROVED', NULL, false, false, true,
 'system', 1700000000000, 'system', 1700000000000, 3, false)
ON CONFLICT (uuid) DO NOTHING;

-- HCMMUSTERROLL Actions
INSERT INTO public.eg_wf_action_v2 (
  uuid, tenantid, currentstate, action, nextstate, roles, active,
  createdby, createdtime, lastmodifiedby, lastmodifiedtime
) VALUES
-- START -> APPROVAL_PENDING (SUBMIT)
('bb000002-0001-4000-b002-000000000001', 'mz',
 'aa000002-0001-4000-a002-000000000001', 'SUBMIT',
 'aa000002-0001-4000-a002-000000000002',
 'PROXIMITY_SUPERVISOR', true,
 'system', 1700000000000, 'system', 1700000000000),
-- APPROVAL_PENDING -> APPROVED (APPROVE)
('bb000002-0001-4000-b002-000000000002', 'mz',
 'aa000002-0001-4000-a002-000000000002', 'APPROVE',
 'aa000002-0001-4000-a002-000000000003',
 'PROXIMITY_SUPERVISOR', true,
 'system', 1700000000000, 'system', 1700000000000)
ON CONFLICT (uuid) DO NOTHING;


-- ============================================================================
-- 3. PROJECTS
-- ============================================================================
-- Three projects from the Postman collection:
-- 1. Individual (SMC Campaign) - projectTypeId from MDMS for INDIVIDUAL
-- 2. Household (LLIN Bednet) - projectTypeId from MDMS for HOUSEHOLD
-- 3. Household IRS - projectTypeId from MDMS for HOUSEHOLD
--
-- The Postman collection uses MDMS-fetched projectTypeIds. We use fixed values
-- that match the Postman prerequest scripts:
--   individualId = b1107f0c-7a91-4c76-afc2-a279d8a7b76a (hardcoded in prerequest)
--   householdId = dbd45c31-de9e-4e62-a9b6-abb818928fd1 (hardcoded in prerequest)
-- Boundary code: FIRST_PROVINCIA is fetched at runtime; we use a representative code.

-- Fixed project IDs
-- PRJ-INDI-0001: Individual SMC Campaign
-- PRJ-HOUSE-0001: Household LLIN Bednet
-- PRJ-IRS-0001: Household IRS

INSERT INTO public.project (
  id, "tenantId", "projectTypeId", "startDate", "endDate", "isTaskEnabled",
  "additionalDetails", "createdBy", "createdTime", "lastModifiedBy", "lastModifiedTime",
  "rowVersion", "isDeleted"
) VALUES
-- Project 1: Individual SMC Campaign
('PRJ-INDI-0001', 'mz', 'b1107f0c-7a91-4c76-afc2-a279d8a7b76a',
 1700000000000, 1701728000000, true,
 '{"projectType":{"projectTypeId":"b1107f0c-7a91-4c76-afc2-a279d8a7b76a","name":"configuration for Multi Round Campaigns","code":"MR-DN","group":"MALARIA","type":"multiround","beneficiaryType":"INDIVIDUAL","eligibilityCriteria":["All households having members under the age of 18 are eligible.","Prison inmates are eligible."],"taskProcedure":["1 bednet is to be distributed per 2 household members.","If there are 4 household members, 2 bednets should be distributed.","If there are 5 household members, 3 bednets should be distributed."],"resources":[{"productVariantId":"PVAR-2026-02-02-000001","isBaseUnitVariant":false},{"productVariantId":"PVAR-2026-02-02-000002","isBaseUnitVariant":true}],"observationStrategy":"DOT1","validMinAge":3,"validMaxAge":64},"numberOfSessions":"ZERO_SESSIONS"}'::jsonb,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 1, false),

-- Project 2: Household LLIN Bednet
('PRJ-HOUSE-0001', 'mz', 'dbd45c31-de9e-4e62-a9b6-abb818928fd1',
 1700000000000, 1701728000000, true,
 '{"projectType":{"projectTypeId":"dbd45c31-de9e-4e62-a9b6-abb818928fd1","name":"mz project type configuration for LLIN Campaigns","code":"LLIN-mz","group":"MALARIA","beneficiaryType":"HOUSEHOLD","eligibilityCriteria":["All households are eligible.","Prison inmates are eligible."],"dashboardUrls":{"NATIONAL_SUPERVISOR":"/digit-ui/employee/dss/landing/national-health-dashboard","PROVINCIAL_SUPERVISOR":"/digit-ui/employee/dss/dashboard/provincial-health-dashboard","DISTRICT_SUPERVISOR":"/digit-ui/employee/dss/dashboard/district-health-dashboard"},"taskProcedure":["1 bednet is to be distributed per 2 household members.","If there are 4 household members, 2 bednets should be distributed.","If there are 5 household members, 3 bednets should be distributed."],"resources":[{"productVariantId":"PVAR-2026-02-02-000003","isBaseUnitVariant":false}]},"numberOfSessions":"TWO_SESSIONS"}'::jsonb,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 1, false),

-- Project 3: Household IRS
('PRJ-IRS-0001', 'mz', 'dbd45c31-de9e-4e62-a9b6-abb818928fd1',
 1700000000000, 1701728000000, true,
 '{"projectType":{"projectTypeId":"dbd45c31-de9e-4e62-a9b6-abb818928fd1","name":"Project type configuration for IRS - Campaigns","code":"IRS-mz","group":"IRS Campaign","beneficiaryType":"HOUSEHOLD","eligibilityCriteria":["All households are eligible."],"dashboardUrls":{"NATIONAL_SUPERVISOR":"/digit-ui/employee/dss/landing/national-health-dashboard","PROVINCIAL_SUPERVISOR":"/digit-ui/employee/dss/dashboard/provincial-health-dashboard","DISTRICT_SUPERVISOR":"/digit-ui/employee/dss/dashboard/district-health-dashboard"},"taskProcedure":["1 DDT is to be distributed per house.","1 Malathion is to be distributed per house.","1 Pyrethroid is to be distributed per house."],"resources":[{"productVariantId":"PVAR-2026-02-02-000004","isBaseUnitVariant":true},{"productVariantId":"PVAR-2026-02-02-000005","isBaseUnitVariant":true},{"productVariantId":"PVAR-2026-02-02-000006","isBaseUnitVariant":true},{"productVariantId":"PVAR-2026-02-02-000007","isBaseUnitVariant":true},{"productVariantId":"PVAR-2026-02-02-000008","isBaseUnitVariant":true},{"productVariantId":"PVAR-2026-02-02-000009","isBaseUnitVariant":true}]},"numberOfSessions":"TWO_SESSIONS"}'::jsonb,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 1, false)
ON CONFLICT (id) DO NOTHING;


-- ============================================================================
-- 4. FACILITIES (facility + address tables)
-- ============================================================================

-- Address records for facilities
INSERT INTO public.address (
  id, "tenantId", "localityCode", latitude, longitude, type
) VALUES
('ADDR-FAC-0001', 'mz', NULL, 12.34, 123.45, 'PERMANENT'),
('ADDR-FAC-0002', 'mz', NULL, 12.34, 123.45, 'PERMANENT')
ON CONFLICT (id) DO NOTHING;

-- Facility 1
INSERT INTO public.facility (
  id, "tenantId", "isPermanent", name, usage, "storageCapacity",
  "addressId", "additionalDetails",
  "createdBy", "createdTime", "lastModifiedBy", "lastModifiedTime",
  "rowVersion", "isDeleted"
) VALUES
('FAC-0001', 'mz', true, 'Facility bednet MDA-LF-Nairobi', 'Storing Resource', 200,
 'ADDR-FAC-0001',
 '{"schema":"test_e37466be924cjhghjg","version":8,"fields":[{"key":"test_12bc5f24692f","value":"test_bf376bce4c01"}]}'::jsonb,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 1, false),

-- Facility 2 (created in Postman test script callback)
('FAC-0002', 'mz', true, 'Facility bednet MDA-LF-Nairobi', 'Storing Resource', 200,
 'ADDR-FAC-0002',
 '{"schema":"test_e37466be924cjhghjg","version":8,"fields":[{"key":"test_12bc5f24692f","value":"test_bf376bce4c01"}]}'::jsonb,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 1, false)
ON CONFLICT (id) DO NOTHING;


-- ============================================================================
-- 5. PROJECT STAFF
-- ============================================================================
-- All 5 users (excluding superadmin) assigned to all 3 projects = 15 rows
-- From the Postman collection: distUUID, SupervisorUUID, wmUUID, hfReferralUUID, hrmsAdminUUID
-- mapped to: D-0001(104), DS-0001(101), WM-0001(102), HFW-0001(103), HR-PGR-0001(105)

INSERT INTO public.project_staff (
  id, "tenantId", "projectId", "staffId",
  "startDate", "endDate",
  "createdBy", "createdTime", "lastModifiedBy", "lastModifiedTime",
  "rowVersion", "isDeleted"
) VALUES
-- Individual project staff
('PS-INDI-D-0001',   'mz', 'PRJ-INDI-0001', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8091', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-INDI-DS-0001',  'mz', 'PRJ-INDI-0001', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-INDI-WM-0001',  'mz', 'PRJ-INDI-0001', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-INDI-HFW-0001', 'mz', 'PRJ-INDI-0001', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f80', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-INDI-HR-0001',  'mz', 'PRJ-INDI-0001', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8091a2', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),

-- Household LLIN project staff
('PS-HOUSE-D-0001',   'mz', 'PRJ-HOUSE-0001', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8091', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-HOUSE-DS-0001',  'mz', 'PRJ-HOUSE-0001', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-HOUSE-WM-0001',  'mz', 'PRJ-HOUSE-0001', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-HOUSE-HFW-0001', 'mz', 'PRJ-HOUSE-0001', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f80', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-HOUSE-HR-0001',  'mz', 'PRJ-HOUSE-0001', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8091a2', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),

-- IRS project staff
('PS-IRS-D-0001',   'mz', 'PRJ-IRS-0001', 'e5f6a7b8-c9d0-4e1f-2a3b-4c5d6e7f8091', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-IRS-DS-0001',  'mz', 'PRJ-IRS-0001', 'b2c3d4e5-f6a7-4b8c-9d0e-1f2a3b4c5d6e', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-IRS-WM-0001',  'mz', 'PRJ-IRS-0001', 'c3d4e5f6-a7b8-4c9d-0e1f-2a3b4c5d6e7f', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-IRS-HFW-0001', 'mz', 'PRJ-IRS-0001', 'd4e5f6a7-b8c9-4d0e-1f2a-3b4c5d6e7f80', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PS-IRS-HR-0001',  'mz', 'PRJ-IRS-0001', 'f6a7b8c9-d0e1-4f2a-3b4c-5d6e7f8091a2', 1983874101527, 9983874101527, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false)
ON CONFLICT (id) DO NOTHING;


-- ============================================================================
-- 6. PROJECT RESOURCES
-- ============================================================================
-- Product variants are already loaded by 01_seed_data_dump.sql.
-- We reference the latest set: PVAR-2026-02-02-000001 through 000009.
-- Mapping (from the seed dump):
--   SP 250mg     = PVAR-2026-02-02-000001
--   AQ 500mg     = PVAR-2026-02-02-000002
--   Bednet       = PVAR-2026-02-02-000003
--   Sumishield   = PVAR-2026-02-02-000004
--   Fludora      = PVAR-2026-02-02-000005
--   Delt         = PVAR-2026-02-02-000006
--   Acetellic    = PVAR-2026-02-02-000007
--   DOT          = PVAR-2026-02-02-000008
--   Bendiocarb   = PVAR-2026-02-02-000009

INSERT INTO public.project_resource (
  id, "tenantId", "projectId", "productVariantId", "isBaseUnitVariant", type,
  "createdBy", "createdTime", "lastModifiedBy", "lastModifiedTime",
  "rowVersion", "isDeleted"
) VALUES
-- Individual project: SP + AQ
('PR-INDI-SP-0001', 'mz', 'PRJ-INDI-0001', 'PVAR-2026-02-02-000001', false, 'DRUG',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PR-INDI-AQ-0001', 'mz', 'PRJ-INDI-0001', 'PVAR-2026-02-02-000002', false, 'DRUG',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),

-- Household LLIN project: Bednet
('PR-HOUSE-BN-0001', 'mz', 'PRJ-HOUSE-0001', 'PVAR-2026-02-02-000003', false, 'Bednet',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),

-- IRS project: 6 IRS product variants
('PR-IRS-SUMI-0001', 'mz', 'PRJ-IRS-0001', 'PVAR-2026-02-02-000004', false, 'DRUG',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PR-IRS-FLUD-0001', 'mz', 'PRJ-IRS-0001', 'PVAR-2026-02-02-000005', false, 'DRUG',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PR-IRS-DELT-0001', 'mz', 'PRJ-IRS-0001', 'PVAR-2026-02-02-000006', false, 'DRUG',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PR-IRS-ACET-0001', 'mz', 'PRJ-IRS-0001', 'PVAR-2026-02-02-000007', false, 'DRUG',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PR-IRS-DOT-0001', 'mz', 'PRJ-IRS-0001', 'PVAR-2026-02-02-000008', false, 'DRUG',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PR-IRS-BEND-0001', 'mz', 'PRJ-IRS-0001', 'PVAR-2026-02-02-000009', false, 'DRUG',
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000,
 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false)
ON CONFLICT (id) DO NOTHING;


-- ============================================================================
-- 7. PROJECT FACILITIES
-- ============================================================================
-- Each facility linked to each project = 6 rows
-- From Postman: FacilityID1 + FacilityID2 linked to all 3 projects

INSERT INTO public.project_facility (
  id, "tenantId", "projectId", "facilityId",
  "createdBy", "createdTime", "lastModifiedBy", "lastModifiedTime",
  "rowVersion", "isDeleted"
) VALUES
-- Facility 1 -> all projects
('PF-INDI-F1-0001',  'mz', 'PRJ-INDI-0001',  'FAC-0001', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PF-HOUSE-F1-0001', 'mz', 'PRJ-HOUSE-0001', 'FAC-0001', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PF-IRS-F1-0001',   'mz', 'PRJ-IRS-0001',   'FAC-0001', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),

-- Facility 2 -> all projects
('PF-INDI-F2-0001',  'mz', 'PRJ-INDI-0001',  'FAC-0002', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PF-HOUSE-F2-0001', 'mz', 'PRJ-HOUSE-0001', 'FAC-0002', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false),
('PF-IRS-F2-0001',   'mz', 'PRJ-IRS-0001',   'FAC-0002', 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d', 1700000000000, 1, false)
ON CONFLICT (id) DO NOTHING;


-- ============================================================================
-- Done. Summary of seed data created:
-- - 6 users (SU-0001, DS-0001, WM-0001, HFW-0001, D-0001, HR-PGR-0001)
-- - User roles in eg_userrole_v1
-- - PGR workflow (business service + 7 states + 9 actions)
-- - HCMMUSTERROLL workflow (business service + 3 states + 2 actions)
-- - 3 projects (Individual SMC, Household LLIN, Household IRS)
-- - 2 facilities with addresses
-- - 15 project-staff assignments (5 users x 3 projects)
-- - 9 project-resource links
-- - 6 project-facility links
-- ============================================================================
