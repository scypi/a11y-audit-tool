<script setup lang="ts">
import { useToast } from 'primevue/usetoast'
import type { Database } from 'types/supabase'
import type { ExtendedAudit, Project } from 'types/database'
import type { AuditMapValue } from 'types/audit'
import { oneMinuteInMilliseconds, hasTimeElapsedInMinutes } from 'utils/time'

const { isAdmin, isAuditor } = useUser()
const route = useRoute()
const supabase = useSupabaseClient()
const toast = useToast()

const audits = ref<ExtendedAudit[]>([])
const projects = ref<Project[]>([])
const isLoading = ref(true)
const projectId = ref(Number(route.query.projectId))
const showUserAudits = ref(route.query.user === 'me')
const notTestedAuditMap = ref(new Map<number, AuditMapValue>())

const areAllAuditsFinished = computed(() =>
  audits.value.every((audit) => hasTimeElapsedInMinutes(audit.created_at, 15))
)

const axeTableInsertChannel = supabase
  .channel('axe')
  .on(
    'postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'axe' },
    async (payload) => {
      const auditId = payload.new.audit_id
      const item = notTestedAuditMap.value.get(auditId)

      if (!item || item.didAutomaticTestsFail) {
        return
      }

      if (payload.new.errors?.length) {
        item.didAutomaticTestsFail = true
        notTestedAuditMap.value.set(auditId, item)
        await fetchAudits()
        return
      }

      item.automaticTestsCount += 1
      notTestedAuditMap.value.set(auditId, item)

      if (item.automaticTestsCount === item.totalNumberOfAllTests) {
        await fetchAudits()
        toast.add({
          severity: 'info',
          summary: `The audit list has been updated`,
          life: 3000,
        })
      }
    }
  )
  .subscribe()

async function fetchAudits() {
  const { data } = await supabase
    .from('audits')
    .select(
      '*, projects(name), profiles(username, full_name), axe (id, errors)'
    )
    .order('created_at', { ascending: false })

  // @todo: fix possibly infinite issue for issues `Json` type
  // @note: temporary disabled - types are generated by supabase
  audits.value = data || []
  // @ts-ignore: possibly infinite issue
  audits.value
    .filter((audit: ExtendedAudit) => !audit.axe.length)
    .forEach(({ id, config }) => {
      notTestedAuditMap.value.set(id, {
        totalNumberOfAllTests: config.pages.length * config.viewports.length,
        automaticTestsCount: 0,
        didAutomaticTestsFail: false,
      })
    })
}

async function fetchProjects() {
  const supabase = useSupabaseClient<Database>()

  try {
    const { data } = await supabase
      .from('projects')
      .select('*')
      .order('name', { ascending: true })
    projects.value = data || []
  } catch (error) {
    console.error('Error fetching projects:', error)
  }
}

const deleteAudit = async (auditId: number) => {
  const { error } = await supabase.from('audits').delete().eq('id', auditId)
  if (!error) {
    audits.value = audits.value.filter(({ id }) => id !== auditId)

    toast.add({
      severity: 'success',
      summary: `Audit #${auditId} deleted`,
      life: 3000,
    })
  }
}

async function fetchData() {
  try {
    await Promise.all([fetchAudits(), fetchProjects()])
  } catch (error) {
    console.error('Error fetching data:', error)
  } finally {
    isLoading.value = false
  }
}

const timeout = setTimeout(async () => {
  await fetchData()
}, 15 * oneMinuteInMilliseconds)

if (areAllAuditsFinished.value) {
  clearTimeout(timeout)
}

onMounted(async () => {
  await fetchData()
})

onUnmounted(() => {
  supabase.removeChannel(axeTableInsertChannel)
})
</script>

<template>
  <div class="grid">
    <div class="flex justify-between">
      <h1>Audit list</h1>

      <NuxtLink
        v-if="isAdmin || isAuditor"
        to="/audit/new"
        class="p-button-link"
      >
        Add new audit
      </NuxtLink>
    </div>

    <div class="grid">
      <Card
        :pt="{
          content: {
            class: 'flex flex-col',
          },
        }"
        class="mb-6 overflow-auto"
      >
        <template #content>
          <Spinner
            v-if="isLoading"
            class="mx-auto w-20"
          />
          <AuditTable
            v-else-if="audits.length"
            :audits="audits"
            :projects="projects"
            :project-id="projectId"
            :show-user-audits="showUserAudits"
            @delete-audit="deleteAudit"
          />
          <p v-else>Your audit list is empty</p>
        </template>
      </Card>
    </div>
  </div>
</template>
