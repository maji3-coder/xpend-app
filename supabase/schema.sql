-- ═══════════════════════════════════════════════════════════════
--  XPEND — Supabase Schema
--  Run this entire file in: Supabase Dashboard → SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════

-- ── 1. Profiles (extends auth.users) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id        UUID    PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username  TEXT    UNIQUE NOT NULL,
  role      TEXT    NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. Budgets ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.budgets (
  id         UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount     NUMERIC NOT NULL CHECK (amount > 0),
  note       TEXT    DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── 3. Expenses ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.expenses (
  id          UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category    TEXT    NOT NULL CHECK (category IN ('transport','food','misc','purchases')),
  amount      NUMERIC NOT NULL CHECK (amount > 0),
  description TEXT    DEFAULT '',
  date        DATE    DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ── 4. Share Requests ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.share_requests (
  id           UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_id   UUID    NOT NULL REFERENCES public.expenses(id) ON DELETE CASCADE,
  from_user_id UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  to_user_id   UUID    NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  percentage   NUMERIC NOT NULL CHECK (percentage > 0 AND percentage < 100),
  status       TEXT    DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════
--  ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE public.profiles       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.share_requests ENABLE ROW LEVEL SECURITY;

-- Helper: is the current user an admin?
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── Profiles policies ─────────────────────────────────────────────
CREATE POLICY "profiles_select" ON public.profiles
  FOR SELECT USING (true); -- Everyone can read usernames (for share-to picker)

CREATE POLICY "profiles_insert" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- ── Budgets policies ──────────────────────────────────────────────
CREATE POLICY "budgets_select" ON public.budgets
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "budgets_insert" ON public.budgets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "budgets_delete" ON public.budgets
  FOR DELETE USING (auth.uid() = user_id);

-- ── Expenses policies ─────────────────────────────────────────────
CREATE POLICY "expenses_select" ON public.expenses
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "expenses_insert" ON public.expenses
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "expenses_update" ON public.expenses
  FOR UPDATE USING (auth.uid() = user_id OR public.is_admin());

CREATE POLICY "expenses_delete" ON public.expenses
  FOR DELETE USING (auth.uid() = user_id);

-- ── Share requests policies ───────────────────────────────────────
CREATE POLICY "share_select" ON public.share_requests
  FOR SELECT USING (
    auth.uid() = from_user_id OR
    auth.uid() = to_user_id OR
    public.is_admin()
  );

CREATE POLICY "share_insert" ON public.share_requests
  FOR INSERT WITH CHECK (auth.uid() = from_user_id);

CREATE POLICY "share_update" ON public.share_requests
  FOR UPDATE USING (auth.uid() = to_user_id);

-- ═══════════════════════════════════════════════════════════════
--  RPC FUNCTION — Accept share request (atomic)
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.accept_share_request(request_id UUID)
RETURNS JSON AS $$
DECLARE
  v_request  public.share_requests%ROWTYPE;
  v_expense  public.expenses%ROWTYPE;
  v_shared   NUMERIC;
  v_remain   NUMERIC;
BEGIN
  -- Fetch and lock request
  SELECT * INTO v_request
  FROM public.share_requests
  WHERE id = request_id
    AND to_user_id = auth.uid()
    AND status = 'pending'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pending request not found';
  END IF;

  -- Fetch original expense
  SELECT * INTO v_expense
  FROM public.expenses
  WHERE id = v_request.expense_id;

  v_shared := ROUND(v_expense.amount * v_request.percentage / 100.0, 2);
  v_remain := v_expense.amount - v_shared;

  -- Add shared portion as new expense for recipient
  INSERT INTO public.expenses (user_id, category, amount, description, date)
  VALUES (
    auth.uid(),
    v_expense.category,
    v_shared,
    '[Shared] ' || COALESCE(NULLIF(v_expense.description,''), v_expense.category)
               || ' (' || v_request.percentage || '%)',
    v_expense.date
  );

  -- Reduce original expense
  UPDATE public.expenses SET amount = v_remain WHERE id = v_expense.id;

  -- Mark request accepted
  UPDATE public.share_requests SET status = 'accepted' WHERE id = request_id;

  RETURN json_build_object('success', true, 'shared_amount', v_shared);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ═══════════════════════════════════════════════════════════════
--  AUTO-CREATE PROFILE ON SIGNUP
-- ═══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'role', 'user')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ═══════════════════════════════════════════════════════════════
--  SEED USERS
--  Run AFTER schema setup. Creates admin, user1, user2.
--  Passwords: admin=admin123, user1=user123, user2=user123
--  In Supabase Dashboard → Authentication → Users → Add user
--  Use emails: admin@xpend.local / user1@xpend.local / user2@xpend.local
--  Then run the INSERT below to set roles:
-- ═══════════════════════════════════════════════════════════════

-- After creating users via Auth dashboard, run:
-- UPDATE public.profiles SET role = 'admin' WHERE username = 'admin';
