library A_Screening65yo version '0.0.1'

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
parameter GradeDAdequatePriorScreeningLookback default 11 //years

context Patient

define "Initial Population":
  AgeInYearsAt(date from start of "Measurement Period") in Interval[64,75)
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
  (Count("Negative Cervical Cytology Every 3 Years") >= 3)
  or
  (Count(ManagementLibrary."NegativeSurveillanceTests" X where X.date in Interval[start of "Measurement Period" - 10 years, end of "Measurement Period")) >= 2)

define "Negative Cervical Cancer Screening Cytology Alone Within 10 Years":
  (ManagementLibrary.SortedCytologyReports except Cotests.CytologyCotest) CytologyAlone
    where CytologyAlone.date in Interval[start of "Measurement Period" - 10 years, end of "Measurement Period")//should the end of this interval be the date of the last encounter of the measurement period?
    and CytologyAlone.riskTableInput = 'NILM'

define "Negative Cervical Cytology Every 3 Years":
  "Negative Cervical Cancer Screening Cytology Alone Within 10 Years" CytologyAlone
  where CytologyAlone.date in Interval[CytologyAlone.date - 42 months, CytologyAlone.date - 3 years]

define "Cotests":
  from ManagementLibrary.SortedHpvReports HrHPVCotest, ManagementLibrary.SortedCytologyReports CytologyCotest
  where HrHPVCotest.date in Interval[CytologyCotest.date - 1 day, CytologyCotest.date + 1 day]

define "Absence of Cervix":
  ManagementLibrary.AbsenceOrRemovalOfCervix
  or exists C3F.Completed(
    [Procedure: "Removal of Cervix Procedures CPT"]
  )

define "Adequate Screening Start Date":
  Patient.birthDate + 55 years
