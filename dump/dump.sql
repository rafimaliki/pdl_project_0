--
-- PostgreSQL database dump
--

-- Dumped from database version 17.0
-- Dumped by pg_dump version 17.0

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
-- Name: payment_status_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_status_type AS ENUM (
    'waiting',
    'accepted',
    'rejected'
);


--
-- Name: sport_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sport_type AS ENUM (
    'tennis',
    'pickleball',
    'padel'
);


--
-- Name: user_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_type AS ENUM (
    'admin',
    'customer'
);


--
-- Name: check_coach_double_booking(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_coach_double_booking() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM coachavailability
        WHERE
            coach_id = NEW.coach_id AND
            date = NEW.date AND
            hour = NEW.hour AND
            coach_availability_id IS DISTINCT FROM NEW.coach_availability_id
    ) THEN
        RAISE EXCEPTION 'A coach can only have one availability entry per hour on a given date.';
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: check_course_quota(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_course_quota() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    current_pax_sum INT;
    course_quota INT;
BEGIN
    SELECT COALESCE(SUM(pax_count), 0) INTO current_pax_sum
    FROM groupcourseorderdetail
    WHERE course_id = NEW.course_id AND group_course_order_detail_id != NEW.group_course_order_detail_id;

    SELECT quota INTO course_quota
    FROM groupcourses
    WHERE course_id = NEW.course_id;

    IF (current_pax_sum + NEW.pax_count) > course_quota THEN
        RAISE EXCEPTION 'Booking exceeds the course quota. Remaining seats: %', (course_quota - current_pax_sum);
    END IF;

    RETURN NEW;
END;
$$;


--
-- Name: check_field_availability(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_field_availability() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    existing_start_hour INT;
BEGIN
    SELECT hour INTO existing_start_hour
    FROM fieldbookingdetail
    WHERE
        field_id = NEW.field_id AND
        date = NEW.date AND
        (NEW.start_hour < hour + 2 AND NEW.start_hour + 2 > hour);

    IF FOUND THEN
        RAISE EXCEPTION 'Field is already booked from % to % on this date.', existing_start_hour, existing_start_hour + 2;
    END IF;

    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: coachavailability; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coachavailability (
    coach_availability_id integer NOT NULL,
    coach_id integer NOT NULL,
    date date NOT NULL,
    hour integer NOT NULL,
    CONSTRAINT coachavailability_hour_check CHECK (((hour >= 6) AND (hour <= 21)))
);


--
-- Name: coachavailability_coach_availability_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.coachavailability_coach_availability_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: coachavailability_coach_availability_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.coachavailability_coach_availability_id_seq OWNED BY public.coachavailability.coach_availability_id;


--
-- Name: coaches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coaches (
    coach_id integer NOT NULL,
    coach_name character varying(255) NOT NULL,
    sport public.sport_type NOT NULL,
    course_price integer NOT NULL
);


--
-- Name: coaches_coach_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.coaches_coach_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: coaches_coach_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.coaches_coach_id_seq OWNED BY public.coaches.coach_id;


--
-- Name: fieldbookingdetail; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fieldbookingdetail (
    field_booking_detail_id integer NOT NULL,
    field_id integer NOT NULL,
    date date NOT NULL,
    hour integer NOT NULL,
    CONSTRAINT fieldbookingdetail_hour_check CHECK (((hour >= 6) AND (hour <= 20)))
);


--
-- Name: fieldbookingdetail_field_booking_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fieldbookingdetail_field_booking_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fieldbookingdetail_field_booking_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fieldbookingdetail_field_booking_detail_id_seq OWNED BY public.fieldbookingdetail.field_booking_detail_id;


--
-- Name: fields; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fields (
    field_id integer NOT NULL,
    field_name character varying(64) NOT NULL,
    sport public.sport_type NOT NULL,
    rental_price integer NOT NULL
);


--
-- Name: fields_field_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fields_field_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fields_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fields_field_id_seq OWNED BY public.fields.field_id;


--
-- Name: groupcourseorder; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groupcourseorder (
    group_course_order_id integer NOT NULL,
    customer_id integer,
    payment_id integer
);


--
-- Name: groupcourseorder_group_course_order_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.groupcourseorder_group_course_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groupcourseorder_group_course_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.groupcourseorder_group_course_order_id_seq OWNED BY public.groupcourseorder.group_course_order_id;


--
-- Name: groupcourseorderdetail; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groupcourseorderdetail (
    group_course_order_detail_id integer NOT NULL,
    group_course_order_id integer,
    course_id integer,
    pax_count integer NOT NULL
);


--
-- Name: groupcourseorderdetail_group_course_order_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.groupcourseorderdetail_group_course_order_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groupcourseorderdetail_group_course_order_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.groupcourseorderdetail_group_course_order_detail_id_seq OWNED BY public.groupcourseorderdetail.group_course_order_detail_id;


--
-- Name: groupcourses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groupcourses (
    course_id integer NOT NULL,
    course_name character varying(255) NOT NULL,
    coach_id integer,
    sport public.sport_type NOT NULL,
    field_id integer,
    date date NOT NULL,
    start_hour integer NOT NULL,
    course_price integer NOT NULL,
    quota integer NOT NULL,
    CONSTRAINT groupcourses_start_hour_check CHECK (((start_hour >= 6) AND (start_hour <= 20)))
);


--
-- Name: groupcourses_course_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.groupcourses_course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: groupcourses_course_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.groupcourses_course_id_seq OWNED BY public.groupcourses.course_id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    payment_id integer NOT NULL,
    total_payment integer NOT NULL,
    payment_proof text,
    status public.payment_status_type DEFAULT 'waiting'::public.payment_status_type NOT NULL,
    payment_date timestamp without time zone
);


--
-- Name: payments_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_payment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_payment_id_seq OWNED BY public.payments.payment_id;


--
-- Name: privatecourseorder; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.privatecourseorder (
    private_course_order_id integer NOT NULL,
    customer_id integer,
    payment_id integer
);


--
-- Name: privatecourseorder_private_course_order_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.privatecourseorder_private_course_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: privatecourseorder_private_course_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.privatecourseorder_private_course_order_id_seq OWNED BY public.privatecourseorder.private_course_order_id;


--
-- Name: privatecourseorderdetail; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.privatecourseorderdetail (
    private_course_order_detail_id integer NOT NULL,
    private_course_order_id integer,
    coach_availability_id integer
);


--
-- Name: privatecourseorderdetail_private_course_order_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.privatecourseorderdetail_private_course_order_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: privatecourseorderdetail_private_course_order_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.privatecourseorderdetail_private_course_order_detail_id_seq OWNED BY public.privatecourseorderdetail.private_course_order_detail_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    full_name character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    phone_number character varying(20) NOT NULL,
    type public.user_type DEFAULT 'customer'::public.user_type NOT NULL
);


--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: vouchers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vouchers (
    voucher_id integer NOT NULL,
    payment_id integer,
    customer_id integer NOT NULL,
    discount integer NOT NULL,
    expired_at timestamp without time zone NOT NULL,
    used boolean DEFAULT false NOT NULL
);


--
-- Name: vouchers_voucher_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.vouchers_voucher_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: vouchers_voucher_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.vouchers_voucher_id_seq OWNED BY public.vouchers.voucher_id;


--
-- Name: coachavailability coach_availability_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coachavailability ALTER COLUMN coach_availability_id SET DEFAULT nextval('public.coachavailability_coach_availability_id_seq'::regclass);


--
-- Name: coaches coach_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coaches ALTER COLUMN coach_id SET DEFAULT nextval('public.coaches_coach_id_seq'::regclass);


--
-- Name: fieldbookingdetail field_booking_detail_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fieldbookingdetail ALTER COLUMN field_booking_detail_id SET DEFAULT nextval('public.fieldbookingdetail_field_booking_detail_id_seq'::regclass);


--
-- Name: fields field_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fields ALTER COLUMN field_id SET DEFAULT nextval('public.fields_field_id_seq'::regclass);


--
-- Name: groupcourseorder group_course_order_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourseorder ALTER COLUMN group_course_order_id SET DEFAULT nextval('public.groupcourseorder_group_course_order_id_seq'::regclass);


--
-- Name: groupcourseorderdetail group_course_order_detail_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourseorderdetail ALTER COLUMN group_course_order_detail_id SET DEFAULT nextval('public.groupcourseorderdetail_group_course_order_detail_id_seq'::regclass);


--
-- Name: groupcourses course_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourses ALTER COLUMN course_id SET DEFAULT nextval('public.groupcourses_course_id_seq'::regclass);


--
-- Name: payments payment_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN payment_id SET DEFAULT nextval('public.payments_payment_id_seq'::regclass);


--
-- Name: privatecourseorder private_course_order_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privatecourseorder ALTER COLUMN private_course_order_id SET DEFAULT nextval('public.privatecourseorder_private_course_order_id_seq'::regclass);


--
-- Name: privatecourseorderdetail private_course_order_detail_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privatecourseorderdetail ALTER COLUMN private_course_order_detail_id SET DEFAULT nextval('public.privatecourseorderdetail_private_course_order_detail_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Name: vouchers voucher_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vouchers ALTER COLUMN voucher_id SET DEFAULT nextval('public.vouchers_voucher_id_seq'::regclass);


--
-- Data for Name: coachavailability; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.coachavailability (coach_availability_id, coach_id, date, hour) FROM stdin;
\.


--
-- Data for Name: coaches; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.coaches (coach_id, coach_name, sport, course_price) FROM stdin;
\.


--
-- Data for Name: fieldbookingdetail; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fieldbookingdetail (field_booking_detail_id, field_id, date, hour) FROM stdin;
\.


--
-- Data for Name: fields; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.fields (field_id, field_name, sport, rental_price) FROM stdin;
\.


--
-- Data for Name: groupcourseorder; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.groupcourseorder (group_course_order_id, customer_id, payment_id) FROM stdin;
\.


--
-- Data for Name: groupcourseorderdetail; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.groupcourseorderdetail (group_course_order_detail_id, group_course_order_id, course_id, pax_count) FROM stdin;
\.


--
-- Data for Name: groupcourses; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.groupcourses (course_id, course_name, coach_id, sport, field_id, date, start_hour, course_price, quota) FROM stdin;
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.payments (payment_id, total_payment, payment_proof, status, payment_date) FROM stdin;
\.


--
-- Data for Name: privatecourseorder; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.privatecourseorder (private_course_order_id, customer_id, payment_id) FROM stdin;
\.


--
-- Data for Name: privatecourseorderdetail; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.privatecourseorderdetail (private_course_order_detail_id, private_course_order_id, coach_availability_id) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.users (user_id, full_name, password_hash, email, phone_number, type) FROM stdin;
\.


--
-- Data for Name: vouchers; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.vouchers (voucher_id, payment_id, customer_id, discount, expired_at, used) FROM stdin;
\.


--
-- Name: coachavailability_coach_availability_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.coachavailability_coach_availability_id_seq', 1, false);


--
-- Name: coaches_coach_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.coaches_coach_id_seq', 1, false);


--
-- Name: fieldbookingdetail_field_booking_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fieldbookingdetail_field_booking_detail_id_seq', 1, false);


--
-- Name: fields_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.fields_field_id_seq', 1, false);


--
-- Name: groupcourseorder_group_course_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.groupcourseorder_group_course_order_id_seq', 1, false);


--
-- Name: groupcourseorderdetail_group_course_order_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.groupcourseorderdetail_group_course_order_detail_id_seq', 1, false);


--
-- Name: groupcourses_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.groupcourses_course_id_seq', 1, false);


--
-- Name: payments_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.payments_payment_id_seq', 1, false);


--
-- Name: privatecourseorder_private_course_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.privatecourseorder_private_course_order_id_seq', 1, false);


--
-- Name: privatecourseorderdetail_private_course_order_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.privatecourseorderdetail_private_course_order_detail_id_seq', 1, false);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.users_user_id_seq', 1, false);


--
-- Name: vouchers_voucher_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.vouchers_voucher_id_seq', 1, false);


--
-- Name: coachavailability coachavailability_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coachavailability
    ADD CONSTRAINT coachavailability_pkey PRIMARY KEY (coach_availability_id);


--
-- Name: coaches coaches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coaches
    ADD CONSTRAINT coaches_pkey PRIMARY KEY (coach_id);


--
-- Name: fieldbookingdetail fieldbookingdetail_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fieldbookingdetail
    ADD CONSTRAINT fieldbookingdetail_pkey PRIMARY KEY (field_booking_detail_id);


--
-- Name: fields fields_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (field_id);


--
-- Name: groupcourseorder groupcourseorder_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourseorder
    ADD CONSTRAINT groupcourseorder_pkey PRIMARY KEY (group_course_order_id);


--
-- Name: groupcourseorderdetail groupcourseorderdetail_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourseorderdetail
    ADD CONSTRAINT groupcourseorderdetail_pkey PRIMARY KEY (group_course_order_detail_id);


--
-- Name: groupcourses groupcourses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourses
    ADD CONSTRAINT groupcourses_pkey PRIMARY KEY (course_id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (payment_id);


--
-- Name: privatecourseorder privatecourseorder_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privatecourseorder
    ADD CONSTRAINT privatecourseorder_pkey PRIMARY KEY (private_course_order_id);


--
-- Name: privatecourseorderdetail privatecourseorderdetail_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privatecourseorderdetail
    ADD CONSTRAINT privatecourseorderdetail_pkey PRIMARY KEY (private_course_order_detail_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: vouchers vouchers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT vouchers_pkey PRIMARY KEY (voucher_id);


--
-- Name: groupcourseorderdetail check_course_quota_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER check_course_quota_trigger BEFORE INSERT OR UPDATE ON public.groupcourseorderdetail FOR EACH ROW EXECUTE FUNCTION public.check_course_quota();


--
-- Name: coachavailability prevent_coach_double_booking_trigger; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_coach_double_booking_trigger BEFORE INSERT OR UPDATE ON public.coachavailability FOR EACH ROW EXECUTE FUNCTION public.check_coach_double_booking();


--
-- Name: groupcourses prevent_double_booking; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER prevent_double_booking BEFORE INSERT OR UPDATE ON public.groupcourses FOR EACH ROW EXECUTE FUNCTION public.check_field_availability();


--
-- Name: coachavailability coachavailability_coach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coachavailability
    ADD CONSTRAINT coachavailability_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES public.coaches(coach_id) ON DELETE CASCADE;


--
-- Name: fieldbookingdetail fieldbookingdetail_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fieldbookingdetail
    ADD CONSTRAINT fieldbookingdetail_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.fields(field_id) ON DELETE CASCADE;


--
-- Name: groupcourseorder groupcourseorder_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourseorder
    ADD CONSTRAINT groupcourseorder_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: groupcourseorder groupcourseorder_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourseorder
    ADD CONSTRAINT groupcourseorder_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(payment_id) ON DELETE CASCADE;


--
-- Name: groupcourseorderdetail groupcourseorderdetail_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourseorderdetail
    ADD CONSTRAINT groupcourseorderdetail_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.groupcourses(course_id) ON DELETE CASCADE;


--
-- Name: groupcourseorderdetail groupcourseorderdetail_group_course_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourseorderdetail
    ADD CONSTRAINT groupcourseorderdetail_group_course_order_id_fkey FOREIGN KEY (group_course_order_id) REFERENCES public.groupcourseorder(group_course_order_id) ON DELETE CASCADE;


--
-- Name: groupcourses groupcourses_coach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourses
    ADD CONSTRAINT groupcourses_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES public.coaches(coach_id) ON DELETE SET NULL;


--
-- Name: groupcourses groupcourses_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groupcourses
    ADD CONSTRAINT groupcourses_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.fields(field_id) ON DELETE SET NULL;


--
-- Name: privatecourseorder privatecourseorder_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privatecourseorder
    ADD CONSTRAINT privatecourseorder_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: privatecourseorder privatecourseorder_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privatecourseorder
    ADD CONSTRAINT privatecourseorder_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(payment_id) ON DELETE CASCADE;


--
-- Name: privatecourseorderdetail privatecourseorderdetail_coach_availability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privatecourseorderdetail
    ADD CONSTRAINT privatecourseorderdetail_coach_availability_id_fkey FOREIGN KEY (coach_availability_id) REFERENCES public.coachavailability(coach_availability_id) ON DELETE CASCADE;


--
-- Name: privatecourseorderdetail privatecourseorderdetail_private_course_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privatecourseorderdetail
    ADD CONSTRAINT privatecourseorderdetail_private_course_order_id_fkey FOREIGN KEY (private_course_order_id) REFERENCES public.privatecourseorder(private_course_order_id) ON DELETE CASCADE;


--
-- Name: vouchers vouchers_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT vouchers_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: vouchers vouchers_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT vouchers_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(payment_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

