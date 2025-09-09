--
-- PostgreSQL database dump
--

-- Dumped from database version 16.3
-- Dumped by pg_dump version 16.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: payment_status_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.payment_status_type AS ENUM (
    'waiting',
    'accepted',
    'rejected'
);


ALTER TYPE public.payment_status_type OWNER TO postgres;

--
-- Name: sport_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.sport_type AS ENUM (
    'tennis',
    'pickleball',
    'padel'
);


ALTER TYPE public.sport_type OWNER TO postgres;

--
-- Name: user_type; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.user_type AS ENUM (
    'admin',
    'customer'
);


ALTER TYPE public.user_type OWNER TO postgres;

--
-- Name: check_coach_double_booking(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.check_coach_double_booking() OWNER TO postgres;

--
-- Name: check_course_quota(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.check_course_quota() OWNER TO postgres;

--
-- Name: check_field_availability(); Type: FUNCTION; Schema: public; Owner: postgres
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


ALTER FUNCTION public.check_field_availability() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: coachavailability; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coachavailability (
    coach_availability_id integer NOT NULL,
    coach_id integer NOT NULL,
    date date NOT NULL,
    hour integer NOT NULL,
    CONSTRAINT coachavailability_hour_check CHECK (((hour >= 6) AND (hour <= 21)))
);


ALTER TABLE public.coachavailability OWNER TO postgres;

--
-- Name: coachavailability_coach_availability_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.coachavailability_coach_availability_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.coachavailability_coach_availability_id_seq OWNER TO postgres;

--
-- Name: coachavailability_coach_availability_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.coachavailability_coach_availability_id_seq OWNED BY public.coachavailability.coach_availability_id;


--
-- Name: coaches; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.coaches (
    coach_id integer NOT NULL,
    coach_name character varying(255) NOT NULL,
    sport public.sport_type NOT NULL,
    course_price integer NOT NULL
);


ALTER TABLE public.coaches OWNER TO postgres;

--
-- Name: coaches_coach_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.coaches_coach_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.coaches_coach_id_seq OWNER TO postgres;

--
-- Name: coaches_coach_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.coaches_coach_id_seq OWNED BY public.coaches.coach_id;


--
-- Name: fieldbookingdetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fieldbookingdetail (
    field_booking_detail_id integer NOT NULL,
    field_id integer NOT NULL,
    date date NOT NULL,
    hour integer NOT NULL,
    CONSTRAINT fieldbookingdetail_hour_check CHECK (((hour >= 6) AND (hour <= 20)))
);


ALTER TABLE public.fieldbookingdetail OWNER TO postgres;

--
-- Name: fieldbookingdetail_field_booking_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fieldbookingdetail_field_booking_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fieldbookingdetail_field_booking_detail_id_seq OWNER TO postgres;

--
-- Name: fieldbookingdetail_field_booking_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fieldbookingdetail_field_booking_detail_id_seq OWNED BY public.fieldbookingdetail.field_booking_detail_id;


--
-- Name: fields; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fields (
    field_id integer NOT NULL,
    field_name character varying(64) NOT NULL,
    sport public.sport_type NOT NULL,
    rental_price integer NOT NULL
);


ALTER TABLE public.fields OWNER TO postgres;

--
-- Name: fields_field_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fields_field_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fields_field_id_seq OWNER TO postgres;

--
-- Name: fields_field_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fields_field_id_seq OWNED BY public.fields.field_id;


--
-- Name: groupcourseorder; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.groupcourseorder (
    group_course_order_id integer NOT NULL,
    customer_id integer,
    payment_id integer
);


ALTER TABLE public.groupcourseorder OWNER TO postgres;

--
-- Name: groupcourseorder_group_course_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.groupcourseorder_group_course_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.groupcourseorder_group_course_order_id_seq OWNER TO postgres;

--
-- Name: groupcourseorder_group_course_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.groupcourseorder_group_course_order_id_seq OWNED BY public.groupcourseorder.group_course_order_id;


--
-- Name: groupcourseorderdetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.groupcourseorderdetail (
    group_course_order_detail_id integer NOT NULL,
    group_course_order_id integer,
    course_id integer,
    pax_count integer NOT NULL
);


ALTER TABLE public.groupcourseorderdetail OWNER TO postgres;

--
-- Name: groupcourseorderdetail_group_course_order_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.groupcourseorderdetail_group_course_order_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.groupcourseorderdetail_group_course_order_detail_id_seq OWNER TO postgres;

--
-- Name: groupcourseorderdetail_group_course_order_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.groupcourseorderdetail_group_course_order_detail_id_seq OWNED BY public.groupcourseorderdetail.group_course_order_detail_id;


--
-- Name: groupcourses; Type: TABLE; Schema: public; Owner: postgres
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


ALTER TABLE public.groupcourses OWNER TO postgres;

--
-- Name: groupcourses_course_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.groupcourses_course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.groupcourses_course_id_seq OWNER TO postgres;

--
-- Name: groupcourses_course_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.groupcourses_course_id_seq OWNED BY public.groupcourses.course_id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    payment_id integer NOT NULL,
    total_payment integer NOT NULL,
    payment_proof text,
    status public.payment_status_type DEFAULT 'waiting'::public.payment_status_type NOT NULL,
    payment_date timestamp without time zone
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.payments_payment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_payment_id_seq OWNER TO postgres;

--
-- Name: payments_payment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.payments_payment_id_seq OWNED BY public.payments.payment_id;


--
-- Name: privatecourseorder; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.privatecourseorder (
    private_course_order_id integer NOT NULL,
    customer_id integer,
    payment_id integer
);


ALTER TABLE public.privatecourseorder OWNER TO postgres;

--
-- Name: privatecourseorder_private_course_order_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.privatecourseorder_private_course_order_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.privatecourseorder_private_course_order_id_seq OWNER TO postgres;

--
-- Name: privatecourseorder_private_course_order_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.privatecourseorder_private_course_order_id_seq OWNED BY public.privatecourseorder.private_course_order_id;


--
-- Name: privatecourseorderdetail; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.privatecourseorderdetail (
    private_course_order_detail_id integer NOT NULL,
    private_course_order_id integer,
    coach_availability_id integer
);


ALTER TABLE public.privatecourseorderdetail OWNER TO postgres;

--
-- Name: privatecourseorderdetail_private_course_order_detail_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.privatecourseorderdetail_private_course_order_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.privatecourseorderdetail_private_course_order_detail_id_seq OWNER TO postgres;

--
-- Name: privatecourseorderdetail_private_course_order_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.privatecourseorderdetail_private_course_order_detail_id_seq OWNED BY public.privatecourseorderdetail.private_course_order_detail_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    full_name character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    email character varying(255) NOT NULL,
    phone_number character varying(20) NOT NULL,
    type public.user_type DEFAULT 'customer'::public.user_type NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_user_id_seq OWNER TO postgres;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: vouchers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.vouchers (
    voucher_id integer NOT NULL,
    payment_id integer,
    customer_id integer NOT NULL,
    discount integer NOT NULL,
    expired_at timestamp without time zone NOT NULL,
    used boolean DEFAULT false NOT NULL
);


ALTER TABLE public.vouchers OWNER TO postgres;

--
-- Name: vouchers_voucher_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.vouchers_voucher_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.vouchers_voucher_id_seq OWNER TO postgres;

--
-- Name: vouchers_voucher_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.vouchers_voucher_id_seq OWNED BY public.vouchers.voucher_id;


--
-- Name: coachavailability coach_availability_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coachavailability ALTER COLUMN coach_availability_id SET DEFAULT nextval('public.coachavailability_coach_availability_id_seq'::regclass);


--
-- Name: coaches coach_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coaches ALTER COLUMN coach_id SET DEFAULT nextval('public.coaches_coach_id_seq'::regclass);


--
-- Name: fieldbookingdetail field_booking_detail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fieldbookingdetail ALTER COLUMN field_booking_detail_id SET DEFAULT nextval('public.fieldbookingdetail_field_booking_detail_id_seq'::regclass);


--
-- Name: fields field_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fields ALTER COLUMN field_id SET DEFAULT nextval('public.fields_field_id_seq'::regclass);


--
-- Name: groupcourseorder group_course_order_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourseorder ALTER COLUMN group_course_order_id SET DEFAULT nextval('public.groupcourseorder_group_course_order_id_seq'::regclass);


--
-- Name: groupcourseorderdetail group_course_order_detail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourseorderdetail ALTER COLUMN group_course_order_detail_id SET DEFAULT nextval('public.groupcourseorderdetail_group_course_order_detail_id_seq'::regclass);


--
-- Name: groupcourses course_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourses ALTER COLUMN course_id SET DEFAULT nextval('public.groupcourses_course_id_seq'::regclass);


--
-- Name: payments payment_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments ALTER COLUMN payment_id SET DEFAULT nextval('public.payments_payment_id_seq'::regclass);


--
-- Name: privatecourseorder private_course_order_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.privatecourseorder ALTER COLUMN private_course_order_id SET DEFAULT nextval('public.privatecourseorder_private_course_order_id_seq'::regclass);


--
-- Name: privatecourseorderdetail private_course_order_detail_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.privatecourseorderdetail ALTER COLUMN private_course_order_detail_id SET DEFAULT nextval('public.privatecourseorderdetail_private_course_order_detail_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Name: vouchers voucher_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vouchers ALTER COLUMN voucher_id SET DEFAULT nextval('public.vouchers_voucher_id_seq'::regclass);


--
-- Data for Name: coachavailability; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coachavailability (coach_availability_id, coach_id, date, hour) FROM stdin;
1	1	2025-09-10	6
2	1	2025-09-26	14
3	1	2025-09-12	14
4	1	2025-09-25	11
5	1	2025-10-01	18
6	1	2025-10-08	10
7	1	2025-09-28	8
8	1	2025-09-18	7
9	1	2025-09-18	17
10	1	2025-09-26	19
11	1	2025-09-21	6
12	1	2025-10-07	16
13	1	2025-10-07	11
14	1	2025-09-22	15
15	1	2025-09-11	8
16	1	2025-09-13	12
17	1	2025-10-08	8
18	1	2025-09-11	12
19	1	2025-09-12	16
20	1	2025-09-11	21
21	2	2025-10-08	17
22	2	2025-09-27	12
23	2	2025-09-16	19
24	2	2025-10-02	17
25	2	2025-09-23	9
26	2	2025-09-12	7
27	2	2025-10-04	15
28	2	2025-09-20	11
29	2	2025-09-30	21
30	2	2025-09-18	18
31	2	2025-09-30	10
32	2	2025-10-03	13
33	2	2025-09-16	16
34	2	2025-09-30	9
35	2	2025-09-21	15
36	2	2025-09-17	20
37	2	2025-09-27	7
38	2	2025-09-11	10
39	2	2025-09-19	15
40	2	2025-10-02	14
41	3	2025-09-27	12
42	3	2025-09-27	7
43	3	2025-09-08	12
44	3	2025-10-03	11
45	3	2025-09-29	12
46	3	2025-09-10	20
47	3	2025-09-21	20
48	3	2025-09-24	10
49	3	2025-10-02	7
50	3	2025-09-22	13
51	3	2025-09-26	10
52	3	2025-09-15	13
53	3	2025-09-18	20
54	3	2025-09-23	13
55	3	2025-10-06	15
56	3	2025-10-08	13
57	3	2025-09-16	18
58	3	2025-09-18	7
59	3	2025-09-28	19
60	3	2025-10-08	6
61	4	2025-09-12	19
62	4	2025-10-07	6
63	4	2025-09-15	7
64	4	2025-09-16	21
65	4	2025-09-10	13
66	4	2025-10-08	13
67	4	2025-09-17	15
68	4	2025-09-18	8
69	4	2025-09-22	20
70	4	2025-10-02	21
71	4	2025-09-16	13
72	4	2025-09-09	8
73	4	2025-09-13	16
74	4	2025-09-15	21
75	4	2025-09-12	16
76	4	2025-09-24	15
77	4	2025-09-19	15
78	4	2025-09-21	15
79	4	2025-09-10	7
80	4	2025-09-26	6
81	5	2025-09-15	21
82	5	2025-09-10	6
83	5	2025-09-29	6
84	5	2025-10-01	10
85	5	2025-09-11	9
86	5	2025-10-02	15
87	5	2025-09-13	14
88	5	2025-09-14	6
89	5	2025-09-23	15
90	5	2025-10-08	17
91	5	2025-10-06	18
92	5	2025-10-03	6
93	5	2025-09-19	19
94	5	2025-09-23	21
95	5	2025-09-09	14
96	5	2025-09-24	15
97	5	2025-09-12	19
98	5	2025-09-27	19
99	5	2025-09-08	18
100	5	2025-09-17	17
101	6	2025-09-20	14
102	6	2025-09-29	8
103	6	2025-09-14	15
104	6	2025-10-02	6
105	6	2025-09-18	16
106	6	2025-10-01	7
107	6	2025-09-12	19
108	6	2025-09-22	6
109	6	2025-09-18	21
110	6	2025-09-16	13
111	6	2025-09-11	10
112	6	2025-09-08	19
113	6	2025-09-26	13
114	6	2025-10-07	17
115	6	2025-09-25	15
116	6	2025-09-15	10
117	6	2025-10-06	12
118	6	2025-09-30	21
119	6	2025-09-28	18
120	6	2025-09-21	20
121	7	2025-09-26	16
122	7	2025-09-30	16
123	7	2025-10-01	20
124	7	2025-10-01	21
125	7	2025-10-08	8
126	7	2025-09-28	9
127	7	2025-09-27	14
128	7	2025-09-17	20
129	7	2025-09-19	16
130	7	2025-09-10	7
131	7	2025-10-05	18
132	7	2025-09-16	6
133	7	2025-10-05	12
134	7	2025-10-02	16
135	7	2025-10-01	18
136	7	2025-10-05	14
137	7	2025-10-05	13
138	7	2025-09-11	12
139	7	2025-09-27	16
140	7	2025-09-11	13
141	8	2025-09-13	20
142	8	2025-09-11	10
143	8	2025-10-06	19
144	8	2025-09-19	10
145	8	2025-10-08	10
146	8	2025-10-07	20
147	8	2025-09-17	13
148	8	2025-09-17	10
149	8	2025-09-28	20
150	8	2025-09-19	7
151	8	2025-09-28	10
152	8	2025-09-23	10
153	8	2025-09-26	20
154	8	2025-09-23	6
155	8	2025-09-11	6
156	8	2025-09-28	12
157	8	2025-09-08	19
158	8	2025-09-15	11
159	8	2025-09-10	20
160	8	2025-10-04	19
161	9	2025-09-15	10
162	9	2025-09-20	18
163	9	2025-09-08	19
164	9	2025-10-05	8
165	9	2025-09-14	8
166	9	2025-09-15	19
167	9	2025-10-05	18
168	9	2025-09-21	18
169	9	2025-09-11	10
170	9	2025-10-07	9
171	9	2025-10-03	11
172	9	2025-09-30	8
173	9	2025-09-18	12
174	9	2025-09-15	20
175	9	2025-09-11	20
176	9	2025-09-08	6
177	9	2025-09-16	14
178	9	2025-10-07	18
179	9	2025-10-07	10
180	9	2025-09-17	18
181	10	2025-09-17	6
182	10	2025-10-07	13
183	10	2025-10-04	11
184	10	2025-09-08	14
185	10	2025-10-03	21
186	10	2025-09-12	7
187	10	2025-10-06	18
188	10	2025-09-20	20
189	10	2025-09-28	10
190	10	2025-09-26	14
191	10	2025-10-06	15
192	10	2025-09-22	15
193	10	2025-09-28	11
194	10	2025-09-19	7
195	10	2025-10-03	12
196	10	2025-10-02	7
197	10	2025-09-21	20
198	10	2025-09-24	12
199	10	2025-09-27	18
200	10	2025-09-24	14
201	11	2025-09-25	8
202	11	2025-09-18	12
203	11	2025-09-09	15
204	11	2025-10-02	9
205	11	2025-10-04	12
206	11	2025-09-23	16
207	11	2025-09-25	7
208	11	2025-10-08	18
209	11	2025-09-19	13
210	11	2025-09-25	17
211	11	2025-09-28	14
212	11	2025-10-08	20
213	11	2025-10-04	13
214	11	2025-09-11	21
215	11	2025-09-23	19
216	11	2025-09-16	9
217	11	2025-10-07	16
218	11	2025-10-01	9
219	11	2025-10-04	8
220	11	2025-09-27	21
221	12	2025-09-29	17
222	12	2025-09-25	17
223	12	2025-09-24	18
224	12	2025-09-28	8
225	12	2025-09-24	7
226	12	2025-10-08	20
227	12	2025-10-01	7
228	12	2025-09-15	20
229	12	2025-09-22	15
230	12	2025-09-23	8
231	12	2025-09-28	14
232	12	2025-10-02	7
233	12	2025-09-21	14
234	12	2025-09-21	13
235	12	2025-09-24	21
236	12	2025-09-30	10
237	12	2025-10-07	18
238	12	2025-09-26	17
239	12	2025-09-10	16
240	12	2025-09-19	18
241	13	2025-09-21	8
242	13	2025-10-04	6
243	13	2025-10-07	13
244	13	2025-09-22	17
245	13	2025-09-26	15
246	13	2025-09-24	13
247	13	2025-09-13	12
248	13	2025-09-10	15
249	13	2025-09-17	12
250	13	2025-09-14	12
251	13	2025-10-04	17
252	13	2025-09-22	19
253	13	2025-09-09	12
254	13	2025-09-16	13
255	13	2025-09-30	17
256	13	2025-09-21	6
257	13	2025-10-06	20
258	13	2025-09-11	18
259	13	2025-09-30	7
260	13	2025-09-14	9
261	14	2025-09-24	14
262	14	2025-10-08	20
263	14	2025-09-24	10
264	14	2025-09-30	6
265	14	2025-09-24	20
266	14	2025-09-25	11
267	14	2025-09-09	7
268	14	2025-09-15	15
269	14	2025-10-07	11
270	14	2025-09-18	10
271	14	2025-09-20	11
272	14	2025-09-08	13
273	14	2025-09-14	19
274	14	2025-10-04	12
275	14	2025-09-23	9
276	14	2025-09-25	6
277	14	2025-09-27	12
278	14	2025-10-07	9
279	14	2025-09-12	20
280	14	2025-10-08	16
281	15	2025-09-12	16
282	15	2025-09-19	17
283	15	2025-09-22	12
284	15	2025-09-30	13
285	15	2025-09-20	19
286	15	2025-10-03	20
287	15	2025-09-12	14
288	15	2025-09-23	17
289	15	2025-09-27	19
290	15	2025-09-11	14
291	15	2025-09-22	8
292	15	2025-10-08	7
293	15	2025-09-13	20
294	15	2025-09-26	21
295	15	2025-10-03	15
296	15	2025-09-20	21
297	15	2025-09-11	11
298	15	2025-09-27	17
299	15	2025-09-16	18
300	15	2025-09-23	7
\.


--
-- Data for Name: coaches; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.coaches (coach_id, coach_name, sport, course_price) FROM stdin;
1	Eric Nichols	tennis	150000
2	John Hampton	tennis	125000
3	Samantha Rodriguez	tennis	100000
4	Zachary Turner	tennis	100000
5	Marissa Kelley	tennis	150000
6	Alexis Stone	tennis	200000
7	Megan Miller	pickleball	150000
8	Nicole Wong	pickleball	95000
9	Anthony Flores	pickleball	95000
10	Cathy Owens	pickleball	80000
11	Brittany Thomas	pickleball	80000
12	Philip Lucero	padel	120000
13	Amber Gonzalez	padel	160000
14	Phillip Gardner	padel	80000
15	Brian Harris	padel	140000
\.


--
-- Data for Name: fieldbookingdetail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fieldbookingdetail (field_booking_detail_id, field_id, date, hour) FROM stdin;
1	1	2025-09-21	9
2	1	2025-09-22	18
3	1	2025-09-17	12
4	1	2025-09-19	10
5	1	2025-09-08	18
6	2	2025-09-21	18
7	2	2025-09-15	14
8	2	2025-09-18	10
9	2	2025-09-12	6
10	2	2025-09-10	17
11	2	2025-09-10	14
12	3	2025-09-17	10
13	3	2025-09-19	10
14	3	2025-09-15	14
15	3	2025-09-09	13
16	3	2025-09-11	16
17	4	2025-09-18	13
18	4	2025-09-10	13
19	4	2025-09-22	14
20	4	2025-09-10	9
21	4	2025-09-22	16
22	4	2025-09-20	9
23	5	2025-09-13	16
24	5	2025-09-21	6
25	5	2025-09-14	9
26	5	2025-09-22	10
27	5	2025-09-22	18
28	5	2025-09-11	18
29	6	2025-09-21	12
30	6	2025-09-18	10
31	6	2025-09-08	10
32	6	2025-09-22	15
33	6	2025-09-14	8
34	6	2025-09-08	15
35	7	2025-09-13	7
36	7	2025-09-17	8
37	7	2025-09-21	10
38	7	2025-09-08	6
39	7	2025-09-19	10
40	7	2025-09-12	13
41	8	2025-09-19	7
42	8	2025-09-22	13
43	8	2025-09-15	13
44	8	2025-09-10	12
45	8	2025-09-10	7
46	8	2025-09-18	7
47	9	2025-09-18	8
48	9	2025-09-09	8
49	9	2025-09-17	10
50	9	2025-09-20	13
51	9	2025-09-14	16
52	9	2025-09-08	16
53	10	2025-09-13	13
54	10	2025-09-17	13
55	10	2025-09-09	10
56	10	2025-09-18	18
57	10	2025-09-14	7
58	10	2025-09-20	18
59	11	2025-09-20	9
60	11	2025-09-13	18
61	11	2025-09-20	12
62	11	2025-09-17	14
63	11	2025-09-10	7
64	11	2025-09-09	13
65	12	2025-09-17	10
66	12	2025-09-16	11
67	12	2025-09-20	17
68	12	2025-09-18	13
69	12	2025-09-08	6
\.


--
-- Data for Name: fields; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fields (field_id, field_name, sport, rental_price) FROM stdin;
1	Tennis Field 1	tennis	300000
2	Tennis Field 2	tennis	400000
3	Tennis Field 3	tennis	550000
4	Tennis Field 4	tennis	300000
5	Tennis Field 5	tennis	300000
6	Pickleball Field 6	pickleball	400000
7	Pickleball Field 7	pickleball	160000
8	Pickleball Field 8	pickleball	320000
9	Pickleball Field 9	pickleball	190000
10	Padel Field 10	padel	450000
11	Padel Field 11	padel	160000
12	Padel Field 12	padel	320000
\.


--
-- Data for Name: groupcourseorder; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.groupcourseorder (group_course_order_id, customer_id, payment_id) FROM stdin;
1	6	10
2	46	11
3	45	11
4	7	29
5	50	7
6	37	29
7	35	20
8	38	16
9	13	6
10	45	29
11	12	8
12	36	6
13	21	16
14	49	16
15	30	14
\.


--
-- Data for Name: groupcourseorderdetail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.groupcourseorderdetail (group_course_order_detail_id, group_course_order_id, course_id, pax_count) FROM stdin;
1	1	22	1
2	2	25	5
3	3	19	1
4	4	17	4
5	5	7	6
6	6	12	5
7	7	21	3
8	8	4	5
9	9	13	5
10	10	20	6
11	11	9	5
12	12	6	7
13	13	18	5
14	14	1	5
15	15	15	6
\.


--
-- Data for Name: groupcourses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.groupcourses (course_id, course_name, coach_id, sport, field_id, date, start_hour, course_price, quota) FROM stdin;
1	Tennis Group Course 1	6	tennis	1	2025-09-21	7	200000	14
2	Padel Group Course 2	14	padel	11	2025-09-20	14	220000	5
3	Tennis Group Course 3	2	tennis	3	2025-09-21	17	450000	13
4	Pickleball Group Course 4	11	pickleball	8	2025-09-09	8	300000	19
5	Tennis Group Course 5	2	tennis	3	2025-09-19	7	200000	6
6	Padel Group Course 6	12	padel	11	2025-09-16	11	450000	17
7	Tennis Group Course 7	3	tennis	2	2025-09-20	10	200000	16
8	Tennis Group Course 8	5	tennis	5	2025-09-16	14	500000	13
9	Padel Group Course 9	12	padel	12	2025-09-13	15	300000	9
10	Tennis Group Course 10	4	tennis	2	2025-09-19	13	450000	9
11	Pickleball Group Course 11	11	pickleball	6	2025-09-14	15	150000	17
12	Tennis Group Course 12	1	tennis	4	2025-09-11	19	500000	20
13	Tennis Group Course 13	2	tennis	2	2025-09-20	20	500000	11
14	Padel Group Course 14	14	padel	11	2025-09-11	6	260000	6
15	Tennis Group Course 15	3	tennis	1	2025-09-18	9	250000	8
16	Padel Group Course 16	12	padel	12	2025-09-10	16	300000	7
17	Tennis Group Course 17	3	tennis	4	2025-09-22	7	300000	13
18	Padel Group Course 18	13	padel	11	2025-09-13	6	260000	5
19	Pickleball Group Course 19	7	pickleball	7	2025-09-20	19	300000	19
20	Tennis Group Course 20	1	tennis	1	2025-09-22	11	400000	9
21	Padel Group Course 21	14	padel	11	2025-09-22	6	180000	8
22	Pickleball Group Course 22	7	pickleball	8	2025-09-21	19	270000	11
23	Padel Group Course 23	13	padel	10	2025-09-17	15	420000	6
24	Pickleball Group Course 24	9	pickleball	6	2025-09-17	16	180000	5
25	Padel Group Course 25	13	padel	12	2025-09-09	9	380000	7
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (payment_id, total_payment, payment_proof, status, payment_date) FROM stdin;
1	500000	\N	waiting	\N
2	500000	\N	waiting	\N
3	300000	proof_2_4460.jpg	accepted	2025-09-03 14:35:15.817042
4	1000000	proof_3_7533.jpg	accepted	2025-08-13 14:35:15.817042
5	100000	proof_4_9847.jpg	rejected	2025-08-18 14:35:15.818043
6	400000	proof_5_8824.jpg	accepted	2025-08-09 14:35:15.818043
7	100000	proof_6_8327.jpg	accepted	2025-09-06 14:35:15.818043
8	750000	proof_7_9934.jpg	accepted	2025-09-01 14:35:15.818043
9	100000	proof_8_6470.jpg	rejected	2025-09-01 14:35:15.818043
10	1000000	proof_9_6867.jpg	accepted	2025-08-26 14:35:15.818043
11	750000	proof_10_6007.jpg	accepted	2025-08-16 14:35:15.818043
12	150000	proof_11_6795.jpg	accepted	2025-09-07 14:35:15.819044
13	750000	\N	waiting	\N
14	150000	proof_13_5654.jpg	accepted	2025-08-11 14:35:15.819044
15	150000	\N	waiting	\N
16	500000	proof_15_2086.jpg	accepted	2025-08-13 14:35:15.819044
17	100000	proof_16_3380.jpg	accepted	2025-08-26 14:35:15.819044
18	200000	proof_17_1255.jpg	accepted	2025-08-11 14:35:15.819044
19	250000	proof_18_9528.jpg	accepted	2025-09-05 14:35:15.819044
20	300000	proof_19_8884.jpg	accepted	2025-08-28 14:35:15.819044
21	1000000	proof_20_8984.jpg	rejected	2025-08-25 14:35:15.819044
22	500000	\N	waiting	\N
23	1000000	proof_22_5933.jpg	accepted	2025-08-13 14:35:15.819044
24	200000	\N	waiting	\N
25	250000	proof_24_7954.jpg	accepted	2025-08-12 14:35:15.819044
26	750000	proof_25_6203.jpg	accepted	2025-09-05 14:35:15.819044
27	500000	proof_26_3175.jpg	accepted	2025-08-25 14:35:15.820561
28	500000	proof_27_9957.jpg	accepted	2025-08-31 14:35:15.820561
29	1000000	proof_28_3497.jpg	accepted	2025-08-29 14:35:15.820561
30	500000	proof_29_2929.jpg	accepted	2025-09-01 14:35:15.820561
\.


--
-- Data for Name: privatecourseorder; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.privatecourseorder (private_course_order_id, customer_id, payment_id) FROM stdin;
1	37	25
2	22	23
3	21	29
4	19	29
5	17	30
6	31	19
7	18	19
8	37	10
9	25	6
10	16	28
11	49	12
12	50	28
13	35	23
14	11	17
15	14	11
16	44	10
17	47	17
18	8	17
19	15	29
20	39	19
21	37	28
22	6	10
23	34	11
24	48	23
25	37	11
26	41	23
27	46	14
28	40	16
29	19	20
30	11	4
31	34	10
32	43	7
33	23	3
34	29	26
35	45	30
36	24	12
37	32	28
38	14	29
39	38	7
40	31	6
41	32	8
42	23	17
43	46	28
44	29	28
45	17	16
46	29	29
47	6	16
48	8	17
49	14	8
50	34	28
51	37	20
52	25	3
53	29	8
54	43	27
55	30	14
56	38	19
57	10	26
58	50	14
59	29	6
60	40	18
61	12	10
62	39	10
63	49	14
64	15	18
65	10	12
66	16	19
67	24	29
68	37	20
69	48	20
70	11	26
71	16	19
72	23	28
73	49	18
74	12	16
75	38	19
76	8	26
77	35	3
78	12	3
79	9	19
80	46	25
81	38	28
82	45	17
83	33	7
84	25	7
85	26	27
86	35	16
87	43	19
88	36	30
89	30	18
90	14	19
91	18	26
92	35	12
93	32	18
94	34	25
95	27	20
96	28	30
97	14	4
98	7	17
99	43	27
100	21	7
101	24	4
102	32	29
103	11	3
104	45	26
105	47	6
106	18	17
107	36	11
108	16	25
109	49	20
110	46	25
111	42	19
112	10	4
113	21	26
114	33	19
115	13	25
116	34	8
117	29	3
118	25	3
119	30	27
120	26	20
\.


--
-- Data for Name: privatecourseorderdetail; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.privatecourseorderdetail (private_course_order_detail_id, private_course_order_id, coach_availability_id) FROM stdin;
1	1	12
2	2	213
3	3	286
4	4	45
5	5	270
6	6	65
7	7	84
8	8	77
9	9	158
10	10	293
11	11	176
12	12	210
13	13	8
14	14	193
15	15	282
16	16	32
17	17	227
18	18	11
19	19	250
20	20	275
21	21	273
22	22	162
23	23	122
24	24	51
25	25	190
26	26	96
27	27	265
28	28	88
29	29	171
30	30	234
31	31	156
32	32	150
33	33	9
34	34	283
35	35	196
36	36	72
37	37	177
38	38	25
39	39	217
40	40	279
41	41	70
42	42	299
43	43	289
44	44	85
45	45	161
46	46	46
47	47	281
48	48	13
49	49	117
50	50	237
51	51	241
52	52	244
53	53	93
54	54	259
55	55	235
56	56	141
57	57	81
58	58	254
59	59	163
60	60	90
61	61	10
62	62	183
63	63	153
64	64	58
65	65	115
66	66	284
67	67	79
68	68	239
69	69	89
70	70	189
71	71	211
72	72	212
73	73	129
74	74	15
75	75	195
76	76	133
77	77	57
78	78	166
79	79	109
80	80	280
81	81	40
82	82	205
83	83	167
84	84	118
85	85	296
86	86	236
87	87	43
88	88	222
89	89	55
90	90	95
91	91	19
92	92	258
93	93	50
94	94	157
95	95	33
96	96	300
97	97	285
98	98	146
99	99	269
100	100	294
101	101	173
102	102	92
103	103	256
104	104	229
105	105	194
106	106	249
107	107	203
108	108	159
109	109	224
110	110	276
111	111	97
112	112	6
113	113	178
114	114	91
115	115	23
116	116	151
117	117	147
118	118	266
119	119	14
120	120	175
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (user_id, full_name, password_hash, email, phone_number, type) FROM stdin;
1	Kevin Becker	240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9	kevinbecker145@email.com	+6233364810392	admin
2	Bradley Anderson	240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9	bradleyanderson97@email.com	+6224484738694	admin
3	Charles Thompson	240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9	charlesthompson146@email.com	+6200209428433	admin
4	Alexandria Petersen	240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9	alexandriapetersen741@email.com	+6255177676327	admin
5	David Barajas	240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9	davidbarajas447@email.com	+6276011603130	admin
6	Brandy Navarro	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	brandynavarro121@email.com	+6209890733790	customer
7	Ryan Ellis	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	ryanellis199@email.com	+6285151003385	customer
8	Connor Hunter	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	connorhunter381@email.com	+6238059623382	customer
9	Michael Evans	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	michaelevans603@email.com	+6255704425048	customer
10	Susan Fletcher	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	susanfletcher985@email.com	+6241439860239	customer
11	Erin Trujillo	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	erintrujillo509@email.com	+6249493885456	customer
12	Charles Reed	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	charlesreed991@email.com	+6201725813968	customer
13	Loretta Young	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	lorettayoung67@email.com	+6288693550160	customer
14	Shannon Chaney	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	shannonchaney18@email.com	+6242255439903	customer
15	Robert Neal	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	robertneal730@email.com	+6205471950873	customer
16	Kevin Becker	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	kevinbecker221@email.com	+6278883433150	customer
17	Brandon Rivera	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	brandonrivera393@email.com	+6222999838488	customer
18	Deborah Macias	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	deborahmacias663@email.com	+6226821222856	customer
19	Jamie Patel	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	jamiepatel774@email.com	+6212484939431	customer
20	Michael Beasley	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	michaelbeasley636@email.com	+6281599843591	customer
21	Alexander Daniels	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	alexanderdaniels875@email.com	+6204032492722	customer
22	Ian Cooper	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	iancooper889@email.com	+6231548185315	customer
23	Miguel Brown	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	miguelbrown434@email.com	+6246883918892	customer
24	Valerie Wood DDS	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	valeriewooddds116@email.com	+6210274105804	customer
25	Maria Miller	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	mariamiller429@email.com	+6263053989402	customer
26	Laurie Haynes	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	lauriehaynes863@email.com	+6245512920768	customer
27	Bruce Lang	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	brucelang304@email.com	+6228257182197	customer
28	Devin Flynn	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	devinflynn321@email.com	+6299767803321	customer
29	Elizabeth Hensley	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	elizabethhensley801@email.com	+6286843211554	customer
30	Justin Dorsey	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	justindorsey114@email.com	+6255038968410	customer
31	Amy Thompson	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	amythompson604@email.com	+6272237059228	customer
32	Michael Diaz	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	michaeldiaz998@email.com	+6205754058575	customer
33	Scott Gomez	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	scottgomez423@email.com	+6220162035022	customer
34	Trevor Ritter	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	trevorritter768@email.com	+6295706515270	customer
35	Michael Castillo	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	michaelcastillo932@email.com	+6295842015101	customer
36	Stacy Stokes	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	stacystokes710@email.com	+6238300266649	customer
37	Becky Robinson	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	beckyrobinson465@email.com	+6270521619233	customer
38	Dustin Patterson	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	dustinpatterson229@email.com	+6224523450622	customer
39	Katelyn Morgan	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	katelynmorgan295@email.com	+6250305459631	customer
40	Adam Morrison	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	adammorrison650@email.com	+6265283081865	customer
41	Gary Liu	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	garyliu467@email.com	+6229944925532	customer
42	Benjamin Calderon	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	benjamincalderon57@email.com	+6201771685417	customer
43	Joseph Lopez	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	josephlopez245@email.com	+6221501099096	customer
44	Susan Mcdaniel	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	susanmcdaniel418@email.com	+6235076789019	customer
45	Joshua Murray	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	joshuamurray363@email.com	+6278892594411	customer
46	Frank Thornton	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	frankthornton621@email.com	+6205830521648	customer
47	John Charles II	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	johncharlesii504@email.com	+6259543179876	customer
48	John Moore	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	johnmoore793@email.com	+6212078877017	customer
49	Kelly Anderson	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	kellyanderson573@email.com	+6202443367793	customer
50	Stephen Morrison	b041c0aeb35bb0fa4aa668ca5a920b590196fdaf9a00eb852c9b7f4d123cc6d6	stephenmorrison347@email.com	+6289980600333	customer
\.


--
-- Data for Name: vouchers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.vouchers (voucher_id, payment_id, customer_id, discount, expired_at, used) FROM stdin;
1	\N	6	25	2025-09-20 14:35:15.942425	f
2	\N	7	35	2025-09-11 14:35:15.944436	f
3	12	7	35	2025-10-18 14:35:15.945436	t
4	\N	7	10	2025-11-30 14:35:15.946435	f
5	18	8	20	2025-11-29 14:35:15.947436	t
6	29	9	25	2025-09-17 14:35:15.948046	t
7	\N	9	5	2025-09-12 14:35:15.948046	f
8	\N	9	15	2025-11-24 14:35:15.949054	f
9	\N	9	10	2025-10-28 14:35:15.949642	f
10	3	10	15	2025-10-23 14:35:15.950079	t
11	6	10	20	2025-11-25 14:35:15.950583	t
12	17	10	5	2025-09-22 14:35:15.950583	t
13	\N	10	35	2025-10-01 14:35:15.950583	f
14	\N	11	40	2025-10-13 14:35:15.95159	f
15	26	11	50	2025-09-26 14:35:15.95159	t
16	26	12	25	2025-10-18 14:35:15.952847	t
17	19	13	25	2025-10-24 14:35:15.952847	t
18	\N	14	10	2025-09-09 14:35:15.953847	f
19	\N	14	10	2025-09-21 14:35:15.953847	f
20	\N	14	35	2025-12-03 14:35:15.954847	f
21	12	14	25	2025-11-24 14:35:15.954847	t
22	20	15	50	2025-09-26 14:35:15.955846	t
23	30	15	5	2025-10-22 14:35:15.955846	t
24	19	15	30	2025-11-02 14:35:15.956846	t
25	\N	15	15	2025-09-22 14:35:15.956846	f
26	\N	16	30	2025-09-18 14:35:15.956846	f
27	\N	17	40	2025-09-15 14:35:15.956846	f
28	\N	17	10	2025-09-21 14:35:15.958353	f
29	\N	18	20	2025-09-09 14:35:15.959361	f
30	\N	18	5	2025-10-06 14:35:15.959361	f
31	\N	18	30	2025-10-24 14:35:15.960867	f
32	\N	19	35	2025-09-28 14:35:15.961402	f
33	\N	20	40	2025-09-26 14:35:15.961402	f
34	\N	20	15	2025-12-05 14:35:15.963039	f
35	\N	20	20	2025-10-30 14:35:15.967048	f
36	19	21	25	2025-10-30 14:35:15.968556	t
37	\N	21	40	2025-09-27 14:35:15.969566	f
38	11	22	25	2025-11-15 14:35:15.969566	t
39	10	22	35	2025-11-21 14:35:15.970564	t
40	\N	22	20	2025-09-09 14:35:15.970564	f
41	\N	23	40	2025-09-30 14:35:15.971698	f
42	27	23	10	2025-11-03 14:35:15.971698	t
43	\N	23	35	2025-09-14 14:35:15.973069	f
44	\N	24	50	2025-09-11 14:35:15.973069	f
45	\N	25	30	2025-09-24 14:35:15.973069	f
46	\N	25	40	2025-11-19 14:35:15.974587	f
47	27	25	40	2025-12-03 14:35:15.974587	t
48	\N	25	40	2025-10-25 14:35:15.975868	f
49	28	26	25	2025-09-30 14:35:15.975868	t
50	\N	26	25	2025-12-01 14:35:15.976875	f
51	\N	27	25	2025-09-10 14:35:15.976875	f
52	\N	27	50	2025-09-12 14:35:15.977873	f
53	16	27	15	2025-11-20 14:35:15.977873	t
54	\N	27	25	2025-12-07 14:35:15.978875	f
55	6	28	40	2025-09-24 14:35:15.978875	t
56	12	29	50	2025-10-08 14:35:15.980383	t
57	\N	30	40	2025-11-20 14:35:15.980383	f
58	\N	30	40	2025-12-06 14:35:15.981388	f
59	\N	31	25	2025-11-14 14:35:15.981893	f
60	\N	31	20	2025-09-10 14:35:15.982573	f
61	\N	31	10	2025-10-15 14:35:15.983021	f
62	\N	32	20	2025-12-01 14:35:15.983021	f
63	\N	33	30	2025-09-10 14:35:15.984028	f
64	\N	34	10	2025-09-30 14:35:15.984028	f
65	\N	35	50	2025-11-23 14:35:15.984028	f
66	\N	36	40	2025-10-30 14:35:15.985027	f
67	\N	37	5	2025-09-12 14:35:15.985027	f
68	\N	37	35	2025-09-16 14:35:15.986027	f
69	23	38	50	2025-11-25 14:35:15.986027	t
70	10	38	5	2025-09-27 14:35:15.986027	t
71	\N	38	35	2025-11-05 14:35:15.987027	f
72	\N	39	50	2025-11-27 14:35:15.987027	f
73	\N	39	50	2025-10-05 14:35:15.988027	f
74	23	40	40	2025-10-05 14:35:15.988027	t
75	\N	40	15	2025-10-25 14:35:15.988027	f
76	\N	40	20	2025-11-13 14:35:15.989027	f
77	30	41	40	2025-09-28 14:35:15.989027	t
78	\N	41	25	2025-11-28 14:35:15.989027	f
79	\N	42	30	2025-11-12 14:35:15.989027	f
80	\N	43	40	2025-09-12 14:35:15.990531	f
81	20	43	25	2025-09-30 14:35:15.990531	t
82	23	43	30	2025-09-26 14:35:15.992046	t
83	26	43	5	2025-09-28 14:35:15.992046	t
84	27	44	10	2025-10-15 14:35:15.993104	t
85	\N	44	35	2025-09-20 14:35:15.993104	f
86	\N	45	15	2025-09-27 14:35:15.994109	f
87	\N	45	10	2025-10-01 14:35:15.994109	f
88	6	46	25	2025-10-26 14:35:15.995113	t
89	27	46	15	2025-11-22 14:35:15.995113	t
90	\N	46	5	2025-10-31 14:35:15.996111	f
91	\N	46	20	2025-10-15 14:35:15.996111	f
92	11	47	30	2025-09-18 14:35:15.99711	t
93	\N	47	30	2025-09-15 14:35:15.99711	f
94	10	48	30	2025-09-21 14:35:15.998111	t
95	\N	48	40	2025-11-14 14:35:15.998111	f
96	27	49	35	2025-11-16 14:35:15.998111	t
97	\N	49	40	2025-10-23 14:35:15.999328	f
98	30	50	25	2025-11-13 14:35:15.999701	t
\.


--
-- Name: coachavailability_coach_availability_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.coachavailability_coach_availability_id_seq', 300, true);


--
-- Name: coaches_coach_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.coaches_coach_id_seq', 15, true);


--
-- Name: fieldbookingdetail_field_booking_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fieldbookingdetail_field_booking_detail_id_seq', 69, true);


--
-- Name: fields_field_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fields_field_id_seq', 12, true);


--
-- Name: groupcourseorder_group_course_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.groupcourseorder_group_course_order_id_seq', 15, true);


--
-- Name: groupcourseorderdetail_group_course_order_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.groupcourseorderdetail_group_course_order_detail_id_seq', 15, true);


--
-- Name: groupcourses_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.groupcourses_course_id_seq', 25, true);


--
-- Name: payments_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_payment_id_seq', 30, true);


--
-- Name: privatecourseorder_private_course_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.privatecourseorder_private_course_order_id_seq', 120, true);


--
-- Name: privatecourseorderdetail_private_course_order_detail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.privatecourseorderdetail_private_course_order_detail_id_seq', 120, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_user_id_seq', 50, true);


--
-- Name: vouchers_voucher_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vouchers_voucher_id_seq', 98, true);


--
-- Name: coachavailability coachavailability_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coachavailability
    ADD CONSTRAINT coachavailability_pkey PRIMARY KEY (coach_availability_id);


--
-- Name: coaches coaches_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coaches
    ADD CONSTRAINT coaches_pkey PRIMARY KEY (coach_id);


--
-- Name: fieldbookingdetail fieldbookingdetail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fieldbookingdetail
    ADD CONSTRAINT fieldbookingdetail_pkey PRIMARY KEY (field_booking_detail_id);


--
-- Name: fields fields_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fields
    ADD CONSTRAINT fields_pkey PRIMARY KEY (field_id);


--
-- Name: groupcourseorder groupcourseorder_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourseorder
    ADD CONSTRAINT groupcourseorder_pkey PRIMARY KEY (group_course_order_id);


--
-- Name: groupcourseorderdetail groupcourseorderdetail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourseorderdetail
    ADD CONSTRAINT groupcourseorderdetail_pkey PRIMARY KEY (group_course_order_detail_id);


--
-- Name: groupcourses groupcourses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourses
    ADD CONSTRAINT groupcourses_pkey PRIMARY KEY (course_id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (payment_id);


--
-- Name: privatecourseorder privatecourseorder_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.privatecourseorder
    ADD CONSTRAINT privatecourseorder_pkey PRIMARY KEY (private_course_order_id);


--
-- Name: privatecourseorderdetail privatecourseorderdetail_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.privatecourseorderdetail
    ADD CONSTRAINT privatecourseorderdetail_pkey PRIMARY KEY (private_course_order_detail_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: vouchers vouchers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT vouchers_pkey PRIMARY KEY (voucher_id);


--
-- Name: groupcourseorderdetail check_course_quota_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_course_quota_trigger BEFORE INSERT OR UPDATE ON public.groupcourseorderdetail FOR EACH ROW EXECUTE FUNCTION public.check_course_quota();


--
-- Name: coachavailability prevent_coach_double_booking_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER prevent_coach_double_booking_trigger BEFORE INSERT OR UPDATE ON public.coachavailability FOR EACH ROW EXECUTE FUNCTION public.check_coach_double_booking();


--
-- Name: groupcourses prevent_double_booking; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER prevent_double_booking BEFORE INSERT OR UPDATE ON public.groupcourses FOR EACH ROW EXECUTE FUNCTION public.check_field_availability();


--
-- Name: coachavailability coachavailability_coach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.coachavailability
    ADD CONSTRAINT coachavailability_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES public.coaches(coach_id) ON DELETE CASCADE;


--
-- Name: fieldbookingdetail fieldbookingdetail_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fieldbookingdetail
    ADD CONSTRAINT fieldbookingdetail_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.fields(field_id) ON DELETE CASCADE;


--
-- Name: groupcourseorder groupcourseorder_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourseorder
    ADD CONSTRAINT groupcourseorder_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: groupcourseorder groupcourseorder_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourseorder
    ADD CONSTRAINT groupcourseorder_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(payment_id) ON DELETE CASCADE;


--
-- Name: groupcourseorderdetail groupcourseorderdetail_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourseorderdetail
    ADD CONSTRAINT groupcourseorderdetail_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.groupcourses(course_id) ON DELETE CASCADE;


--
-- Name: groupcourseorderdetail groupcourseorderdetail_group_course_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourseorderdetail
    ADD CONSTRAINT groupcourseorderdetail_group_course_order_id_fkey FOREIGN KEY (group_course_order_id) REFERENCES public.groupcourseorder(group_course_order_id) ON DELETE CASCADE;


--
-- Name: groupcourses groupcourses_coach_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourses
    ADD CONSTRAINT groupcourses_coach_id_fkey FOREIGN KEY (coach_id) REFERENCES public.coaches(coach_id) ON DELETE SET NULL;


--
-- Name: groupcourses groupcourses_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.groupcourses
    ADD CONSTRAINT groupcourses_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.fields(field_id) ON DELETE SET NULL;


--
-- Name: privatecourseorder privatecourseorder_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.privatecourseorder
    ADD CONSTRAINT privatecourseorder_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: privatecourseorder privatecourseorder_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.privatecourseorder
    ADD CONSTRAINT privatecourseorder_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(payment_id) ON DELETE CASCADE;


--
-- Name: privatecourseorderdetail privatecourseorderdetail_coach_availability_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.privatecourseorderdetail
    ADD CONSTRAINT privatecourseorderdetail_coach_availability_id_fkey FOREIGN KEY (coach_availability_id) REFERENCES public.coachavailability(coach_availability_id) ON DELETE CASCADE;


--
-- Name: privatecourseorderdetail privatecourseorderdetail_private_course_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.privatecourseorderdetail
    ADD CONSTRAINT privatecourseorderdetail_private_course_order_id_fkey FOREIGN KEY (private_course_order_id) REFERENCES public.privatecourseorder(private_course_order_id) ON DELETE CASCADE;


--
-- Name: vouchers vouchers_customer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT vouchers_customer_id_fkey FOREIGN KEY (customer_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: vouchers vouchers_payment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.vouchers
    ADD CONSTRAINT vouchers_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payments(payment_id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

