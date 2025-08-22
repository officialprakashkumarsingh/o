-- ============================================
-- SUPABASE CHAT HISTORY SCHEMA
-- ============================================
-- Copy this entire file and run it in Supabase SQL Editor
-- This will create all necessary tables and functions for chat history

-- Create chat_sessions table
CREATE TABLE IF NOT EXISTS public.chat_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true,
    message_count INTEGER DEFAULT 0
);

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES public.chat_sessions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    model_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user_id ON public.chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_updated_at ON public.chat_sessions(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session_id ON public.chat_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at);

-- Enable Row Level Security (RLS)
ALTER TABLE public.chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for chat_sessions
CREATE POLICY "Users can view their own chat sessions" 
    ON public.chat_sessions FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own chat sessions" 
    ON public.chat_sessions FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own chat sessions" 
    ON public.chat_sessions FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own chat sessions" 
    ON public.chat_sessions FOR DELETE 
    USING (auth.uid() = user_id);

-- Create RLS policies for chat_messages
CREATE POLICY "Users can view their own messages" 
    ON public.chat_messages FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can create their own messages" 
    ON public.chat_messages FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own messages" 
    ON public.chat_messages FOR UPDATE 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own messages" 
    ON public.chat_messages FOR DELETE 
    USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for updating updated_at on chat_sessions
CREATE TRIGGER update_chat_sessions_updated_at
    BEFORE UPDATE ON public.chat_sessions
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Create function to increment message count
CREATE OR REPLACE FUNCTION public.increment_message_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.chat_sessions 
    SET message_count = message_count + 1,
        updated_at = NOW()
    WHERE id = NEW.session_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for incrementing message count
CREATE TRIGGER increment_session_message_count
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.increment_message_count();

-- Create function to get or create active session
CREATE OR REPLACE FUNCTION public.get_or_create_active_session(p_user_id UUID)
RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
BEGIN
    -- Try to get active session
    SELECT id INTO v_session_id
    FROM public.chat_sessions
    WHERE user_id = p_user_id 
    AND is_active = true
    ORDER BY updated_at DESC
    LIMIT 1;
    
    -- If no active session, create one
    IF v_session_id IS NULL THEN
        INSERT INTO public.chat_sessions (user_id, title)
        VALUES (p_user_id, 'New Chat')
        RETURNING id INTO v_session_id;
    END IF;
    
    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to generate session title from first message
CREATE OR REPLACE FUNCTION public.generate_session_title()
RETURNS TRIGGER AS $$
BEGIN
    -- Only update title if it's still "New Chat" and this is a user message
    IF NEW.role = 'user' THEN
        UPDATE public.chat_sessions
        SET title = LEFT(NEW.content, 50)
        WHERE id = NEW.session_id 
        AND title = 'New Chat';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-generate session title
CREATE TRIGGER auto_generate_session_title
    AFTER INSERT ON public.chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.generate_session_title();

-- Grant necessary permissions
GRANT ALL ON public.chat_sessions TO authenticated;
GRANT ALL ON public.chat_messages TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_active_session TO authenticated;

-- Create view for session summaries
CREATE OR REPLACE VIEW public.chat_session_summaries AS
SELECT 
    cs.id,
    cs.user_id,
    cs.title,
    cs.created_at,
    cs.updated_at,
    cs.is_active,
    cs.message_count,
    (
        SELECT content 
        FROM public.chat_messages 
        WHERE session_id = cs.id 
        AND role = 'user'
        ORDER BY created_at DESC 
        LIMIT 1
    ) as last_user_message,
    (
        SELECT created_at 
        FROM public.chat_messages 
        WHERE session_id = cs.id 
        ORDER BY created_at DESC 
        LIMIT 1
    ) as last_message_at
FROM public.chat_sessions cs;

-- Grant access to the view
GRANT SELECT ON public.chat_session_summaries TO authenticated;

-- ============================================
-- END OF SCHEMA
-- ============================================