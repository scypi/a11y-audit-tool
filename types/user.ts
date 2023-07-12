import type { User } from '@supabase/gotrue-js'
import type { Profile, Project } from 'types/database'

export interface UserClaim {
  provider: string
  providers: string[]
  user_role?: 'auditor' | 'viewer'
  claims_admin?: boolean
}

export interface ProfileWithEmail extends Profile {
  email: string
}

export interface ProfileProject {
  name: Project['name']
  email: User['email']
}
