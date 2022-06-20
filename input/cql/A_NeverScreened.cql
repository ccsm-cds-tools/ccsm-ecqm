library A_NeverScreened version '0.0.1'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1' called FHIRHelpers
include TopLevelScreeningLibrary version '1.0.0' called TLSL
include HospiceFHIR4_2022 version '4.0.000' called Hospice
include PalliativeCareExclusionFHIR4_2022 version '2.0.000' called PalliativeCare
include ManagementLibrary version '1.0.0' called ManagementLibrary
include CDSConnectCommonsforFHIRv401 version '1.0.0' called C3F
include AdultOutpatientEncountersFHIR4_2022 version '3.0.000' called AdultOutpatient
include DisplayCervicalCancerMedicalHistory version '1.0.0' called Dash

valueset "Removal of Cervix Procedures CPT": 'http://cts.nlm.nih.gov/fhir/ValueSet/2.16.840.1.113883.3.464.1003.198.11.1026'

parameter "Measurement Period" Interval<DateTime> default Interval[@2020-01-01T00:00:00.0, @2021-01-01T00:00:00.0)

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") in Interval[24, 65)
    and TLSL.FemaleorTransgenderMale
    and exists AdultOutpatient."Qualifying Encounters"

define "Denominator":
  "Initial Population"

define "Denominator Exclusions":
  Hospice."Has Hospice Services"
  or PalliativeCare."Palliative Care in the Measurement Period"
  or ("Absence of Cervix"
    and not
      (ManagementLibrary."HasHighGradePreCancerCervicalLesion"
      or ManagementLibrary."HasCervicalCancerDiagnoses"
      or exists Dash."HighGradeOrCancerHistologyResults")
    )

define "Numerator":
  Count("Cervical Cytology Within 10 Years" union Dash.CervicalCytologyReports) = 0
  and Count("HPV Test Within 10 Years" union Dash.HpvDiagnosticReports) = 0

define "Absence of Cervix":
  ManagementLibrary.AbsenceOrRemovalOfCervix
  or exists C3F.Completed(
    [Procedure: "Removal of Cervix Procedures CPT"]
  )

define "Cervical Cytology Within 10 Years":
  [Observation: Dash."Pap Test"] CervicalCytology
    where CervicalCytology.status in {'final', 'amended', 'corrected'}
      and CervicalCytology.effective 10 years or less on or before end of "Measurement Period" //would screening during measurement period be included if this was changed to "...start of measurement period"
      //and CervicalCytology.value is not null

define "HPV Test Within 10 Years":
  [Observation: Dash."HPV Test"] HPVTest
    where HPVTest.status in {'final', 'amended', 'corrected'}
      and HPVTest.effective 10 years or less on or before end of "Measurement Period" //would screening during measurement period be included if this was changed to "...start of measurement period"
      //and HPVTest.value is not null
