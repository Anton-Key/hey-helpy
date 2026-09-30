--
-- PostgreSQL database dump
--

\restrict KE5wt8zq9ThD0pwhhKCAZYFNS8XHy6vAz4uGvAnXKUGujZNaEVAkRKKHVoQfE31

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.11 (Ubuntu 17.11-1.pgdg24.04+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name')
  on conflict (id) do nothing;
  return new;
end;
$$;


--
-- Name: my_company_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.my_company_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select company_id from public.profiles where id = auth.uid();
$$;


--
-- Name: my_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.my_role() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select role from public.profiles where id = auth.uid();
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_anchors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_anchors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asset_id uuid NOT NULL,
    anchor_id text NOT NULL,
    lat double precision,
    lng double precision,
    pose jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: assets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.assets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    location_id uuid NOT NULL,
    name text NOT NULL,
    category text DEFAULT 'equipment'::text,
    inventory_no text,
    meta jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT assets_category_check CHECK ((category = ANY (ARRAY['equipment'::text, 'furniture'::text, 'infra'::text, 'other'::text])))
);


--
-- Name: attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    work_order_id uuid NOT NULL,
    kind text DEFAULT 'photo'::text NOT NULL,
    storage_path text NOT NULL,
    lat double precision,
    lng double precision,
    taken_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT attachments_kind_check CHECK ((kind = ANY (ARRAY['photo'::text, 'audio'::text, 'video'::text, 'model'::text])))
);


--
-- Name: checklist_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checklist_items (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    work_order_id uuid NOT NULL,
    text text NOT NULL,
    is_done boolean DEFAULT false NOT NULL,
    done_at timestamp with time zone,
    done_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contractor_objects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contractor_objects (
    contractor_id uuid NOT NULL,
    object_id uuid NOT NULL
);


--
-- Name: contractors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contractors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    org_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: departments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.departments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    object_id uuid NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: executors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.executors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid,
    contractor_id uuid NOT NULL,
    work_types text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: invites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contractor_id uuid NOT NULL,
    token text DEFAULT encode(extensions.gen_random_bytes(16), 'hex'::text) NOT NULL,
    expires_at timestamp with time zone,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: locations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.locations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    object_id uuid NOT NULL,
    parent_id uuid,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: objects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.objects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    name text NOT NULL,
    type text DEFAULT 'office'::text NOT NULL,
    address text,
    lat double precision,
    lng double precision,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT objects_type_check CHECK ((type = ANY (ARRAY['office'::text, 'hotel'::text, 'apartments'::text, 'warehouse'::text, 'other'::text])))
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    company_id uuid,
    full_name text,
    role text DEFAULT 'requester'::text NOT NULL,
    phone text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT profiles_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'manager'::text, 'requester'::text, 'contractor'::text, 'executor'::text])))
);


--
-- Name: scan_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.scan_tags (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    asset_id uuid,
    location_id uuid,
    code text NOT NULL,
    kind text DEFAULT 'qr'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT scan_tags_kind_check CHECK ((kind = ANY (ARRAY['qr'::text, 'ar'::text])))
);


--
-- Name: work_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    work_order_id uuid NOT NULL,
    from_status text,
    to_status text,
    by_profile uuid,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: work_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.work_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    object_id uuid,
    location_id uuid,
    asset_id uuid,
    title text NOT NULL,
    description text,
    work_type text,
    priority text DEFAULT 'normal'::text NOT NULL,
    status text DEFAULT 'new'::text NOT NULL,
    recurrence jsonb,
    requires_photo boolean DEFAULT false NOT NULL,
    requires_scan boolean DEFAULT false NOT NULL,
    input_channel text DEFAULT 'button'::text,
    created_by uuid,
    assigned_executor_id uuid,
    assigned_by text,
    due_at timestamp with time zone,
    time_spent_minutes integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    assigned_contractor_id uuid,
    CONSTRAINT work_orders_assigned_by_check CHECK ((assigned_by = ANY (ARRAY['ai'::text, 'manager'::text]))),
    CONSTRAINT work_orders_input_channel_check CHECK ((input_channel = ANY (ARRAY['button'::text, 'text'::text, 'voice'::text, 'camera'::text]))),
    CONSTRAINT work_orders_priority_check CHECK ((priority = ANY (ARRAY['low'::text, 'normal'::text, 'high'::text, 'critical'::text]))),
    CONSTRAINT work_orders_status_check CHECK ((status = ANY (ARRAY['new'::text, 'assigned'::text, 'in_progress'::text, 'done'::text, 'cancelled'::text, 'overdue'::text])))
);


--
-- Name: ar_anchors ar_anchors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_anchors
    ADD CONSTRAINT ar_anchors_pkey PRIMARY KEY (id);


--
-- Name: assets assets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_pkey PRIMARY KEY (id);


--
-- Name: attachments attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);


--
-- Name: checklist_items checklist_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_items
    ADD CONSTRAINT checklist_items_pkey PRIMARY KEY (id);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: contractor_objects contractor_objects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contractor_objects
    ADD CONSTRAINT contractor_objects_pkey PRIMARY KEY (contractor_id, object_id);


--
-- Name: contractors contractors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contractors
    ADD CONSTRAINT contractors_pkey PRIMARY KEY (id);


--
-- Name: departments departments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_pkey PRIMARY KEY (id);


--
-- Name: executors executors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.executors
    ADD CONSTRAINT executors_pkey PRIMARY KEY (id);


--
-- Name: invites invites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_pkey PRIMARY KEY (id);


--
-- Name: invites invites_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_token_key UNIQUE (token);


--
-- Name: locations locations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_pkey PRIMARY KEY (id);


--
-- Name: objects objects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.objects
    ADD CONSTRAINT objects_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: scan_tags scan_tags_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_tags
    ADD CONSTRAINT scan_tags_code_key UNIQUE (code);


--
-- Name: scan_tags scan_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_tags
    ADD CONSTRAINT scan_tags_pkey PRIMARY KEY (id);


--
-- Name: work_logs work_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_logs
    ADD CONSTRAINT work_logs_pkey PRIMARY KEY (id);


--
-- Name: work_orders work_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_pkey PRIMARY KEY (id);


--
-- Name: idx_attachments_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_attachments_wo ON public.attachments USING btree (work_order_id);


--
-- Name: idx_checklist_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_checklist_wo ON public.checklist_items USING btree (work_order_id);


--
-- Name: idx_logs_wo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_logs_wo ON public.work_logs USING btree (work_order_id);


--
-- Name: idx_objects_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_objects_company ON public.objects USING btree (company_id);


--
-- Name: idx_wo_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wo_company ON public.work_orders USING btree (company_id);


--
-- Name: idx_wo_contractor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wo_contractor ON public.work_orders USING btree (assigned_contractor_id);


--
-- Name: idx_wo_executor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wo_executor ON public.work_orders USING btree (assigned_executor_id);


--
-- Name: idx_wo_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wo_status ON public.work_orders USING btree (status);


--
-- Name: ar_anchors ar_anchors_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_anchors
    ADD CONSTRAINT ar_anchors_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id) ON DELETE CASCADE;


--
-- Name: assets assets_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.assets
    ADD CONSTRAINT assets_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE CASCADE;


--
-- Name: attachments attachments_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.attachments
    ADD CONSTRAINT attachments_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_orders(id) ON DELETE CASCADE;


--
-- Name: checklist_items checklist_items_done_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_items
    ADD CONSTRAINT checklist_items_done_by_fkey FOREIGN KEY (done_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: checklist_items checklist_items_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checklist_items
    ADD CONSTRAINT checklist_items_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_orders(id) ON DELETE CASCADE;


--
-- Name: contractor_objects contractor_objects_contractor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contractor_objects
    ADD CONSTRAINT contractor_objects_contractor_id_fkey FOREIGN KEY (contractor_id) REFERENCES public.contractors(id) ON DELETE CASCADE;


--
-- Name: contractor_objects contractor_objects_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contractor_objects
    ADD CONSTRAINT contractor_objects_object_id_fkey FOREIGN KEY (object_id) REFERENCES public.objects(id) ON DELETE CASCADE;


--
-- Name: contractors contractors_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contractors
    ADD CONSTRAINT contractors_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: departments departments_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.departments
    ADD CONSTRAINT departments_object_id_fkey FOREIGN KEY (object_id) REFERENCES public.objects(id) ON DELETE CASCADE;


--
-- Name: executors executors_contractor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.executors
    ADD CONSTRAINT executors_contractor_id_fkey FOREIGN KEY (contractor_id) REFERENCES public.contractors(id) ON DELETE CASCADE;


--
-- Name: executors executors_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.executors
    ADD CONSTRAINT executors_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: invites invites_contractor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invites
    ADD CONSTRAINT invites_contractor_id_fkey FOREIGN KEY (contractor_id) REFERENCES public.contractors(id) ON DELETE CASCADE;


--
-- Name: locations locations_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_object_id_fkey FOREIGN KEY (object_id) REFERENCES public.objects(id) ON DELETE CASCADE;


--
-- Name: locations locations_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.locations
    ADD CONSTRAINT locations_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.locations(id) ON DELETE SET NULL;


--
-- Name: objects objects_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.objects
    ADD CONSTRAINT objects_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE SET NULL;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: scan_tags scan_tags_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_tags
    ADD CONSTRAINT scan_tags_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id) ON DELETE CASCADE;


--
-- Name: scan_tags scan_tags_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.scan_tags
    ADD CONSTRAINT scan_tags_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE CASCADE;


--
-- Name: work_logs work_logs_by_profile_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_logs
    ADD CONSTRAINT work_logs_by_profile_fkey FOREIGN KEY (by_profile) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: work_logs work_logs_work_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_logs
    ADD CONSTRAINT work_logs_work_order_id_fkey FOREIGN KEY (work_order_id) REFERENCES public.work_orders(id) ON DELETE CASCADE;


--
-- Name: work_orders work_orders_asset_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_asset_id_fkey FOREIGN KEY (asset_id) REFERENCES public.assets(id) ON DELETE SET NULL;


--
-- Name: work_orders work_orders_assigned_contractor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_assigned_contractor_id_fkey FOREIGN KEY (assigned_contractor_id) REFERENCES public.contractors(id) ON DELETE SET NULL;


--
-- Name: work_orders work_orders_assigned_executor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_assigned_executor_id_fkey FOREIGN KEY (assigned_executor_id) REFERENCES public.executors(id) ON DELETE SET NULL;


--
-- Name: work_orders work_orders_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE CASCADE;


--
-- Name: work_orders work_orders_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id) ON DELETE SET NULL;


--
-- Name: work_orders work_orders_location_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_location_id_fkey FOREIGN KEY (location_id) REFERENCES public.locations(id) ON DELETE SET NULL;


--
-- Name: work_orders work_orders_object_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.work_orders
    ADD CONSTRAINT work_orders_object_id_fkey FOREIGN KEY (object_id) REFERENCES public.objects(id) ON DELETE SET NULL;


--
-- Name: ar_anchors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ar_anchors ENABLE ROW LEVEL SECURITY;

--
-- Name: ar_anchors ar_anchors_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ar_anchors_company ON public.ar_anchors USING ((EXISTS ( SELECT 1
   FROM ((public.assets a
     JOIN public.locations l ON ((l.id = a.location_id)))
     JOIN public.objects o ON ((o.id = l.object_id)))
  WHERE ((a.id = ar_anchors.asset_id) AND (o.company_id = public.my_company_id())))));


--
-- Name: assets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;

--
-- Name: assets assets_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY assets_company ON public.assets USING ((EXISTS ( SELECT 1
   FROM (public.locations l
     JOIN public.objects o ON ((o.id = l.object_id)))
  WHERE ((l.id = assets.location_id) AND (o.company_id = public.my_company_id())))));


--
-- Name: attachments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

--
-- Name: attachments attachments_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY attachments_company ON public.attachments USING ((EXISTS ( SELECT 1
   FROM public.work_orders w
  WHERE ((w.id = attachments.work_order_id) AND (w.company_id = public.my_company_id())))));


--
-- Name: checklist_items checklist_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY checklist_company ON public.checklist_items USING ((EXISTS ( SELECT 1
   FROM public.work_orders w
  WHERE ((w.id = checklist_items.work_order_id) AND (w.company_id = public.my_company_id())))));


--
-- Name: checklist_items; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.checklist_items ENABLE ROW LEVEL SECURITY;

--
-- Name: companies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;

--
-- Name: companies companies_select_members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY companies_select_members ON public.companies FOR SELECT USING ((id = public.my_company_id()));


--
-- Name: contractor_objects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contractor_objects ENABLE ROW LEVEL SECURITY;

--
-- Name: contractor_objects contractor_objects_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contractor_objects_company ON public.contractor_objects USING ((EXISTS ( SELECT 1
   FROM public.contractors c
  WHERE ((c.id = contractor_objects.contractor_id) AND (c.company_id = public.my_company_id())))));


--
-- Name: contractors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contractors ENABLE ROW LEVEL SECURITY;

--
-- Name: contractors contractors_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contractors_company ON public.contractors USING ((company_id = public.my_company_id())) WITH CHECK ((company_id = public.my_company_id()));


--
-- Name: departments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;

--
-- Name: departments departments_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY departments_company ON public.departments USING ((EXISTS ( SELECT 1
   FROM public.objects o
  WHERE ((o.id = departments.object_id) AND (o.company_id = public.my_company_id())))));


--
-- Name: executors; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.executors ENABLE ROW LEVEL SECURITY;

--
-- Name: executors executors_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY executors_company ON public.executors USING ((EXISTS ( SELECT 1
   FROM public.contractors c
  WHERE ((c.id = executors.contractor_id) AND (c.company_id = public.my_company_id())))));


--
-- Name: invites; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;

--
-- Name: invites invites_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY invites_company ON public.invites USING ((EXISTS ( SELECT 1
   FROM public.contractors c
  WHERE ((c.id = invites.contractor_id) AND (c.company_id = public.my_company_id())))));


--
-- Name: locations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;

--
-- Name: locations locations_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY locations_company ON public.locations USING ((EXISTS ( SELECT 1
   FROM public.objects o
  WHERE ((o.id = locations.object_id) AND (o.company_id = public.my_company_id())))));


--
-- Name: objects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.objects ENABLE ROW LEVEL SECURITY;

--
-- Name: objects objects_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY objects_company ON public.objects USING ((company_id = public.my_company_id())) WITH CHECK ((company_id = public.my_company_id()));


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_select_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_company ON public.profiles FOR SELECT USING (((company_id IS NOT NULL) AND (company_id = public.my_company_id())));


--
-- Name: profiles profiles_select_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_self ON public.profiles FOR SELECT USING ((id = auth.uid()));


--
-- Name: profiles profiles_update_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_update_self ON public.profiles FOR UPDATE USING ((id = auth.uid())) WITH CHECK ((id = auth.uid()));


--
-- Name: scan_tags; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.scan_tags ENABLE ROW LEVEL SECURITY;

--
-- Name: scan_tags scan_tags_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY scan_tags_company ON public.scan_tags USING (((EXISTS ( SELECT 1
   FROM ((public.assets a
     JOIN public.locations l ON ((l.id = a.location_id)))
     JOIN public.objects o ON ((o.id = l.object_id)))
  WHERE ((a.id = scan_tags.asset_id) AND (o.company_id = public.my_company_id())))) OR (EXISTS ( SELECT 1
   FROM (public.locations l
     JOIN public.objects o ON ((o.id = l.object_id)))
  WHERE ((l.id = scan_tags.location_id) AND (o.company_id = public.my_company_id()))))));


--
-- Name: work_logs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.work_logs ENABLE ROW LEVEL SECURITY;

--
-- Name: work_logs work_logs_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY work_logs_company ON public.work_logs USING ((EXISTS ( SELECT 1
   FROM public.work_orders w
  WHERE ((w.id = work_logs.work_order_id) AND (w.company_id = public.my_company_id())))));


--
-- Name: work_orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.work_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: work_orders work_orders_company; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY work_orders_company ON public.work_orders USING ((company_id = public.my_company_id())) WITH CHECK ((company_id = public.my_company_id()));


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.handle_new_user() TO anon;
GRANT ALL ON FUNCTION public.handle_new_user() TO authenticated;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--
-- Name: FUNCTION my_company_id(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.my_company_id() TO anon;
GRANT ALL ON FUNCTION public.my_company_id() TO authenticated;
GRANT ALL ON FUNCTION public.my_company_id() TO service_role;


--
-- Name: FUNCTION my_role(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.my_role() TO anon;
GRANT ALL ON FUNCTION public.my_role() TO authenticated;
GRANT ALL ON FUNCTION public.my_role() TO service_role;


--
-- Name: TABLE ar_anchors; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.ar_anchors TO anon;
GRANT ALL ON TABLE public.ar_anchors TO authenticated;
GRANT ALL ON TABLE public.ar_anchors TO service_role;


--
-- Name: TABLE assets; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.assets TO anon;
GRANT ALL ON TABLE public.assets TO authenticated;
GRANT ALL ON TABLE public.assets TO service_role;


--
-- Name: TABLE attachments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.attachments TO anon;
GRANT ALL ON TABLE public.attachments TO authenticated;
GRANT ALL ON TABLE public.attachments TO service_role;


--
-- Name: TABLE checklist_items; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.checklist_items TO anon;
GRANT ALL ON TABLE public.checklist_items TO authenticated;
GRANT ALL ON TABLE public.checklist_items TO service_role;


--
-- Name: TABLE companies; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.companies TO anon;
GRANT ALL ON TABLE public.companies TO authenticated;
GRANT ALL ON TABLE public.companies TO service_role;


--
-- Name: TABLE contractor_objects; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.contractor_objects TO anon;
GRANT ALL ON TABLE public.contractor_objects TO authenticated;
GRANT ALL ON TABLE public.contractor_objects TO service_role;


--
-- Name: TABLE contractors; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.contractors TO anon;
GRANT ALL ON TABLE public.contractors TO authenticated;
GRANT ALL ON TABLE public.contractors TO service_role;


--
-- Name: TABLE departments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.departments TO anon;
GRANT ALL ON TABLE public.departments TO authenticated;
GRANT ALL ON TABLE public.departments TO service_role;


--
-- Name: TABLE executors; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.executors TO anon;
GRANT ALL ON TABLE public.executors TO authenticated;
GRANT ALL ON TABLE public.executors TO service_role;


--
-- Name: TABLE invites; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.invites TO anon;
GRANT ALL ON TABLE public.invites TO authenticated;
GRANT ALL ON TABLE public.invites TO service_role;


--
-- Name: TABLE locations; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.locations TO anon;
GRANT ALL ON TABLE public.locations TO authenticated;
GRANT ALL ON TABLE public.locations TO service_role;


--
-- Name: TABLE objects; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.objects TO anon;
GRANT ALL ON TABLE public.objects TO authenticated;
GRANT ALL ON TABLE public.objects TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.profiles TO anon;
GRANT ALL ON TABLE public.profiles TO authenticated;
GRANT ALL ON TABLE public.profiles TO service_role;


--
-- Name: TABLE scan_tags; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.scan_tags TO anon;
GRANT ALL ON TABLE public.scan_tags TO authenticated;
GRANT ALL ON TABLE public.scan_tags TO service_role;


--
-- Name: TABLE work_logs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.work_logs TO anon;
GRANT ALL ON TABLE public.work_logs TO authenticated;
GRANT ALL ON TABLE public.work_logs TO service_role;


--
-- Name: TABLE work_orders; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.work_orders TO anon;
GRANT ALL ON TABLE public.work_orders TO authenticated;
GRANT ALL ON TABLE public.work_orders TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict KE5wt8zq9ThD0pwhhKCAZYFNS8XHy6vAz4uGvAnXKUGujZNaEVAkRKKHVoQfE31

