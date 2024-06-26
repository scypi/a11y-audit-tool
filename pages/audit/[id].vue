<script lang="ts" setup>
import type { Database } from 'types/supabase'
import type { ScreenSize } from '~/data/screenSizes'
import { availableScreenSizes } from '~/data/screenSizes'

const supabase = useSupabaseClient<Database>()
const route = useRoute()
const router = useRouter()
const auditId = route.params.id
const resultId = ref(Number(route.query.resultId))
const isReloadRequired = ref(false)

const { data: axeResults } = await supabase
  .from('axe')
  .select('*')
  .eq('audit_id', auditId)

const { data: auditInfo } = await supabase
  .from('audits')
  .select('*, projects(name), profiles(username, full_name)')
  .eq('id', auditId)
  .single()

if (!axeResults || !auditInfo) {
  throw createError({
    statusCode: 404,
    statusMessage: 'Audit not found',
    fatal: true,
  })
}

const urlAndSelectorOptions = axeResults?.map((result) => {
  const screenSize = availableScreenSizes.find(
    (availableScreenSize) =>
      availableScreenSize.viewport.toString() === result.size?.toString()
  )
  return {
    id: result.id,
    name: `${result.results?.url} - ${result.selector ?? ''}`,
    screenSize,
  }
})

if (!resultId.value) {
  resultId.value = urlAndSelectorOptions[0]?.id
}

const screenSizeOptions = urlAndSelectorOptions.reduce((acc, result) => {
  if (!acc.find((option) => option.name === result.screenSize?.name)) {
    if (result.screenSize) {
      acc.push(result.screenSize)
    }
  }
  return acc
}, [] as ScreenSize[])

const screenSize = ref(
  urlAndSelectorOptions.find((option) => resultId.value === option.id)
    ?.screenSize || screenSizeOptions[0]
)

const urlAndSelectorOptionsForSelectedScreenSize = computed(() =>
  urlAndSelectorOptions.filter(
    (option) => option.screenSize?.name === screenSize.value.name
  )
)

const changeScreenSize = (value: ScreenSize) => {
  const previousResultName =
    urlAndSelectorOptionsForSelectedScreenSize.value.find(
      (value) => value.id === resultId.value
    )?.name

  screenSize.value = value
  resultId.value =
    urlAndSelectorOptionsForSelectedScreenSize.value.find(
      (option) => option.name === previousResultName
    )?.id || resultId.value
}

const auditResult = computed(() =>
  axeResults.find((result) => result.id === resultId.value)
)

watch(
  resultId,
  () => {
    router.replace({
      query: {
        resultId: resultId.value,
      },
    })
  },
  { immediate: true }
)
</script>

<template>
  <div class="mb-24 space-y-6">
    <template v-if="auditInfo && auditInfo.config">
      <div
        class="flex flex-col-reverse gap-x-2 gap-y-4 md:flex-row md:justify-between"
      >
        <h1 class="font-medium">Audit: {{ auditInfo.config.title }}</h1>
        <div>
          <NuxtLink
            :to="`/audit/new?baseAuditId=${auditId}`"
            class="p-button p-button-outlined"
          >
            Repeat audit
          </NuxtLink>
        </div>
      </div>
      <Accordion>
        <AccordionTab header="Audit Information">
          <ul class="space-y-1">
            <li><span class="font-bold">Id: </span>#{{ auditId }}</li>
            <li>
              <span class="font-bold">Project: </span>
              {{ auditInfo.projects?.name }}
            </li>
            <li v-if="auditInfo.config?.description">
              <span class="font-bold">Description: </span>
              {{ auditInfo.config.description }}
            </li>
            <li>
              <span class="font-bold">Created at: </span>
              <time>
                {{ new Date(auditInfo.created_at).toLocaleDateString('pl-PL') }}
              </time>
            </li>
            <li>
              <span class="font-bold">Auditor: </span>
              {{ auditInfo.profiles?.full_name }} ({{
                auditInfo.profiles?.username
              }})
            </li>
            <li>
              <span class="font-bold">Status: </span>{{ auditInfo.status }}
            </li>
            <li v-if="auditInfo.config?.basicAuth?.username?.length">
              <span class="font-bold">Basic Authentication:</span>
              <ul class="list-disc pl-8">
                <li
                  v-for="(tTValue, tTKey) in auditInfo.config.basicAuth"
                  :key="tTKey"
                >
                  <span class="font-bold first-letter:uppercase">
                    {{ tTKey }}:
                  </span>
                  &nbsp;
                  {{ tTValue }}
                </li>
              </ul>
            </li>
            <li v-if="auditInfo.config.pages.length">
              <span class="font-bold">Pages:</span>
              <ul class="list-disc space-y-2 pl-8">
                <li
                  v-for="(page, index) in auditInfo.config.pages"
                  :key="index"
                >
                  <NuxtLink
                    :to="page.url"
                    target="_blank"
                  >
                    {{ page.url }}
                  </NuxtLink>
                  <template v-if="page.selector?.length">
                    - selector:
                    <code class="break-words rounded-md bg-gray-100 px-2 py-1">
                      {{ page.selector }}
                    </code>
                  </template>
                </li>
              </ul>
            </li>
            <li>
              <span class="font-bold">Screen sizes:</span>
              <ul class="list-disc pl-8">
                <li
                  v-for="(option, index) in urlAndSelectorOptions"
                  :key="index"
                >
                  {{ option.screenSize?.name }} [{{
                    option.screenSize?.viewport[0]
                  }}
                  x {{ option.screenSize?.viewport[1] }}]
                </li>
              </ul>
            </li>
          </ul>
        </AccordionTab>
      </Accordion>
      <div class="grid grid-cols-1 gap-x-6 gap-y-4 md:grid-cols-[2fr_1fr]">
        <div v-if="!auditInfo.config.noAxe">
          <label
            for="url-selector"
            class="mb-2 block font-medium"
          >
            Url and selector
          </label>
          <Dropdown
            v-model="resultId"
            class="w-full"
            :options="urlAndSelectorOptionsForSelectedScreenSize"
            option-label="name"
            option-value="id"
            input-id="url-selector"
            @change="isReloadRequired = true"
          />
        </div>
        <div :class="{ 'col-span-2': auditInfo.config.noAxe }">
          <label
            for="screen-size"
            class="mb-2 block font-medium"
          >
            Screen size / Device
          </label>
          <Dropdown
            :model-value="screenSize"
            class="w-full"
            option-label="name"
            :options="screenSizeOptions"
            input-id="screen-size"
            @update:model-value="changeScreenSize"
            @change="isReloadRequired = true"
          />
        </div>
      </div>
      <Transition
        enter-active-class="transition duration-300 ease-out"
        enter-from-class="transform scale-95 opacity-0"
        enter-to-class="transform scale-100 opacity-100"
        leave-active-class="transition duration-75 ease-in"
        leave-from-class="transform scale-100 opacity-100"
        leave-to-class="transform scale-95 opacity-0"
      >
        <InlineMessage
          v-show="isReloadRequired"
          severity="warn"
          class="flex w-full items-center !justify-start"
        >
          Refresh the page to make sure the correct audit data is displayed.
        </InlineMessage>
      </Transition>
      <AuditResults
        v-if="auditResult"
        :result="auditResult"
      />
    </template>
  </div>
</template>
