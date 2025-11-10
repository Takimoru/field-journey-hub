-- Create app roles enum
CREATE TYPE public.app_role AS ENUM ('admin', 'supervisor', 'team_leader', 'team_member');

-- Create app status enum
CREATE TYPE public.report_status AS ENUM ('draft', 'submitted', 'approved', 'revision_requested');

-- Create profiles table
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  student_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create user_roles table (CRITICAL: separate from profiles for security)
CREATE TABLE public.user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  role app_role NOT NULL,
  UNIQUE(user_id, role)
);

ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

-- Security definer function to check roles
CREATE OR REPLACE FUNCTION public.has_role(_user_id UUID, _role app_role)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = _user_id AND role = _role
  )
$$;

-- Create programs table
CREATE TABLE public.programs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_by UUID REFERENCES auth.users(id) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.programs ENABLE ROW LEVEL SECURITY;

-- Create teams table
CREATE TABLE public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  program_id UUID REFERENCES public.programs(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  leader_id UUID REFERENCES auth.users(id) NOT NULL,
  supervisor_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

-- Create team_members junction table
CREATE TABLE public.team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(team_id, user_id)
);

ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

-- Create attendance table
CREATE TABLE public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  date DATE NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  gps_coordinates POINT,
  photo_url TEXT,
  UNIQUE(team_id, user_id, date)
);

ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

-- Create weekly_tasks table
CREATE TABLE public.weekly_tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  assigned_to UUID REFERENCES auth.users(id),
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  week_number INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.weekly_tasks ENABLE ROW LEVEL SECURITY;

-- Create weekly_reports table
CREATE TABLE public.weekly_reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE NOT NULL,
  week_number INTEGER NOT NULL,
  progress_percentage INTEGER NOT NULL CHECK (progress_percentage >= 0 AND progress_percentage <= 100),
  status report_status NOT NULL DEFAULT 'draft',
  submitted_at TIMESTAMPTZ,
  submitted_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(team_id, week_number)
);

ALTER TABLE public.weekly_reports ENABLE ROW LEVEL SECURITY;

-- Create supervisor_comments table
CREATE TABLE public.supervisor_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id UUID REFERENCES public.weekly_reports(id) ON DELETE CASCADE NOT NULL,
  supervisor_id UUID REFERENCES auth.users(id) NOT NULL,
  comment TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.supervisor_comments ENABLE ROW LEVEL SECURITY;

-- Create storage bucket for photos
INSERT INTO storage.buckets (id, name, public) VALUES ('field-photos', 'field-photos', true);

-- Storage policies for field-photos bucket
CREATE POLICY "Anyone can view photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'field-photos');

CREATE POLICY "Authenticated users can upload photos"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'field-photos' AND auth.uid() IS NOT NULL);

CREATE POLICY "Users can update their own photos"
ON storage.objects FOR UPDATE
USING (bucket_id = 'field-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own photos"
ON storage.objects FOR DELETE
USING (bucket_id = 'field-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- RLS Policies for profiles
CREATE POLICY "Users can view all profiles"
ON public.profiles FOR SELECT
USING (true);

CREATE POLICY "Users can update own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- RLS Policies for user_roles
CREATE POLICY "Users can view their own roles"
ON public.user_roles FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Admins can manage all roles"
ON public.user_roles FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- RLS Policies for programs
CREATE POLICY "Anyone can view non-archived programs"
ON public.programs FOR SELECT
USING (NOT archived OR public.has_role(auth.uid(), 'admin'));

CREATE POLICY "Admins can manage programs"
ON public.programs FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- RLS Policies for teams
CREATE POLICY "Users can view teams they belong to"
ON public.teams FOR SELECT
USING (
  public.has_role(auth.uid(), 'admin') OR
  leader_id = auth.uid() OR
  supervisor_id = auth.uid() OR
  EXISTS (SELECT 1 FROM public.team_members WHERE team_id = id AND user_id = auth.uid())
);

CREATE POLICY "Admins can manage teams"
ON public.teams FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- RLS Policies for team_members
CREATE POLICY "Users can view team members of their teams"
ON public.team_members FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.teams t 
    WHERE t.id = team_id AND (
      t.leader_id = auth.uid() OR
      t.supervisor_id = auth.uid() OR
      public.has_role(auth.uid(), 'admin') OR
      EXISTS (SELECT 1 FROM public.team_members tm WHERE tm.team_id = t.id AND tm.user_id = auth.uid())
    )
  )
);

CREATE POLICY "Admins and leaders can manage team members"
ON public.team_members FOR ALL
USING (
  public.has_role(auth.uid(), 'admin') OR
  EXISTS (SELECT 1 FROM public.teams WHERE id = team_id AND leader_id = auth.uid())
);

-- RLS Policies for attendance
CREATE POLICY "Users can view attendance of their teams"
ON public.attendance FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.teams t 
    WHERE t.id = team_id AND (
      t.leader_id = auth.uid() OR
      t.supervisor_id = auth.uid() OR
      public.has_role(auth.uid(), 'admin') OR
      user_id = auth.uid()
    )
  )
);

CREATE POLICY "Users can insert own attendance"
ON public.attendance FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can manage all attendance"
ON public.attendance FOR ALL
USING (public.has_role(auth.uid(), 'admin'));

-- RLS Policies for weekly_tasks
CREATE POLICY "Team members can view team tasks"
ON public.weekly_tasks FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.teams t 
    WHERE t.id = team_id AND (
      t.leader_id = auth.uid() OR
      t.supervisor_id = auth.uid() OR
      public.has_role(auth.uid(), 'admin') OR
      EXISTS (SELECT 1 FROM public.team_members WHERE team_id = t.id AND user_id = auth.uid())
    )
  )
);

CREATE POLICY "Leaders can manage team tasks"
ON public.weekly_tasks FOR ALL
USING (
  public.has_role(auth.uid(), 'admin') OR
  EXISTS (SELECT 1 FROM public.teams WHERE id = team_id AND leader_id = auth.uid())
);

-- RLS Policies for weekly_reports
CREATE POLICY "Team members can view team reports"
ON public.weekly_reports FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.teams t 
    WHERE t.id = team_id AND (
      t.leader_id = auth.uid() OR
      t.supervisor_id = auth.uid() OR
      public.has_role(auth.uid(), 'admin') OR
      EXISTS (SELECT 1 FROM public.team_members WHERE team_id = t.id AND user_id = auth.uid())
    )
  )
);

CREATE POLICY "Leaders can manage team reports"
ON public.weekly_reports FOR ALL
USING (
  public.has_role(auth.uid(), 'admin') OR
  EXISTS (SELECT 1 FROM public.teams WHERE id = team_id AND leader_id = auth.uid())
);

-- RLS Policies for supervisor_comments
CREATE POLICY "Team members can view supervisor comments"
ON public.supervisor_comments FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM public.weekly_reports wr
    JOIN public.teams t ON t.id = wr.team_id
    WHERE wr.id = report_id AND (
      t.leader_id = auth.uid() OR
      t.supervisor_id = auth.uid() OR
      public.has_role(auth.uid(), 'admin') OR
      EXISTS (SELECT 1 FROM public.team_members WHERE team_id = t.id AND user_id = auth.uid())
    )
  )
);

CREATE POLICY "Supervisors can add comments"
ON public.supervisor_comments FOR INSERT
WITH CHECK (
  auth.uid() = supervisor_id AND
  EXISTS (
    SELECT 1 FROM public.weekly_reports wr
    JOIN public.teams t ON t.id = wr.team_id
    WHERE wr.id = report_id AND t.supervisor_id = auth.uid()
  )
);

-- Trigger function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers
CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_programs_updated_at
BEFORE UPDATE ON public.programs
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_teams_updated_at
BEFORE UPDATE ON public.teams
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_weekly_tasks_updated_at
BEFORE UPDATE ON public.weekly_tasks
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_weekly_reports_updated_at
BEFORE UPDATE ON public.weekly_reports
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Trigger to create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', NEW.email),
    NEW.email
  );
  
  -- Assign default team_member role
  INSERT INTO public.user_roles (user_id, role)
  VALUES (NEW.id, 'team_member');
  
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();