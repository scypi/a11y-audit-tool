import { useToast } from 'primevue/usetoast'

import type { Database, FormDataField, FormData, Result } from 'types/supabase'
import type { AutomaticTestGroupedResult, Audit } from 'types/audit'
import { auditTemplate } from '~/data/auditTemplate'
import type { SupabaseError } from '~/plugins/error'

export function useAudit(
  axeResult?: Database['public']['Tables']['axe']['Row']
) {
  const toast = useToast()
  const isSaving = ref(false)
  const isFormDataEdited = ref(false)

  const formData = ref<FormData>(
    auditTemplate.reduce((acc, test) => {
      const testId = test['Test ID']
      return {
        ...acc,
        [testId]: {
          manualTestResultsStatus:
            axeResult?.form_data?.[testId]?.manualTestResultsStatus ||
            'Not tested',
          manualTestIssues:
            axeResult?.form_data?.[testId]?.manualTestIssues || '',
          manualTestRecommendedFixes:
            axeResult?.form_data?.[testId]?.manualTestRecommendedFixes || '',
        },
      }
    }, {})
  )

  const updateField = ({
    id,
    field,
    value,
  }: {
    id: string
    field: FormDataField
    value: string
  }) => {
    formData.value[id][field] = value
    isFormDataEdited.value = true
  }

  const saveFormData = async () => {
    isSaving.value = true
    const supabase = useSupabaseClient<Database>()

    if (axeResult) {
      try {
        const { data, error } = await supabase
          .from('axe')
          .update({ form_data: formData.value })
          .eq('id', axeResult.id)
          .select()
        if (!error && data?.length === 1) {
          toast.add({
            severity: 'success',
            summary: 'Successfully saved data',
            life: 3000,
          })
          isFormDataEdited.value = false
        }
      } catch (error) {
        const { $handleError } = useNuxtApp()

        $handleError(error as Error | SupabaseError)
      } finally {
        isSaving.value = false
      }
    }
  }

  const audit = ref<Audit>([])

  if (axeResult) {
    const results = toValue(axeResult.results)
    const automaticTestsGroupedResults = [
      {
        type: 'violations',
        results: results.violations || [],
      },
      {
        type: 'passes',
        results: results?.passes || [],
      },
    ]

    auditTemplate.forEach((test) => {
      let automaticTestResultsStatus = 'Not applicable'
      const automaticTestGroupedResults: AutomaticTestGroupedResult[] = []
      automaticTestsGroupedResults.forEach(({ type, results }) => {
        let testResults: Result[] = []
        if (test['Axe Rules']?.tag || test['Axe Rules']?.rules) {
          testResults = results.filter(({ tags, id }) => {
            if (
              typeof test['Axe Rules'].tag === 'string' &&
              tags.includes(test['Axe Rules'].tag)
            ) {
              return true
            }
            if (Array.isArray(test['Axe Rules'].rules)) {
              return test['Axe Rules'].rules.includes(id)
            }
            return false
          })
        }

        automaticTestGroupedResults.push({
          type,
          results: testResults,
        })

        if (!testResults.length) {
          return
        }
        if (type === 'violations') {
          automaticTestResultsStatus = 'Failed'
        } else if (automaticTestResultsStatus !== 'Failed') {
          automaticTestResultsStatus = 'Passed'
        }
      })
      audit.value.push({
        id: test['Test ID'],
        info: test,
        automaticTestGroupedResults,
        automaticTestResultsStatus,
      })
    })
  }

  return {
    audit,
    formData,
    isSaving,
    isFormDataEdited,
    updateField,
    saveFormData,
  }
}
