class Reports::CohortByStartDate
   
  attr_accessor :start_date, :end_date
  @@age_at_initiation_join = '' #'INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient_start_dates.patient_id'
  @@age_at_initiation_join_for_pills = '' #'INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient_whole_tablets_remaining_and_brought.patient_id'
  @@registration_dates_join = '' #'INNER JOIN patient_registration_dates ON patient_registration_dates.patient_id = patient_start_dates.patient_id'

  # NOTE: We include registration_dates_join even when we don't really need in order to have consistent numbers

  def initialize(start_date, end_date)
    @start_date = "#{start_date} 00:00:00"
    @end_date = "#{end_date} 23:59:59"

    @outcome_join = "INNER JOIN ( \
           SELECT * FROM ( \
             SELECT * \
             FROM patient_historical_outcomes \
             INNER JOIN ( \
               SELECT concept_id, 0 AS sort_weight FROM concept WHERE concept_id = 322 \
               UNION SELECT concept_id, 1 AS sort_weight FROM concept WHERE concept_id = 374 \
               UNION SELECT concept_id, 2 AS sort_weight FROM concept WHERE concept_id = 383 \
               UNION SELECT concept_id, 3 AS sort_weight FROM concept WHERE concept_id = 325 \
               UNION SELECT concept_id, 4 AS sort_weight FROM concept WHERE concept_id = 386 \
               UNION SELECT concept_id, 5 AS sort_weight FROM concept WHERE concept_id = 373 \
               UNION SELECT concept_id, 6 AS sort_weight FROM concept WHERE concept_id = 324 \
               UNION SELECT concept_id, 6 AS sort_weight FROM concept WHERE concept_id = 323 \
             ) AS ordered_outcomes ON ordered_outcomes.concept_id = patient_historical_outcomes.outcome_concept_id \
             WHERE outcome_date >= '#{@start_date}' AND outcome_date <= '#{@end_date}' \
             ORDER BY DATE(outcome_date) DESC, sort_weight \
           ) as t GROUP BY t.patient_id \
        ) as outcome ON outcome.patient_id = patient_start_dates.patient_id"
  end
  
  def patients_started_on_arv_therapy(min_age=nil, max_age=nil)
    conditions = ["start_date >= ? AND start_date <= ?", @start_date, @end_date]
    conditions = ["start_date >= ? AND start_date <= ? AND age_at_initiation >= ? AND age_at_initiation <= ?",
                  @start_date, @end_date, min_age, max_age] if min_age and max_age

    PatientStartDate.find(:all, #:joins => "#{@@registration_dates_join}", 
                          :conditions => conditions)
  end
  
  def men_started_on_arv_therapy
    # removed :include because it uses DISTINCT when passed to count. We don't want DISTINCT
    PatientStartDate.find(:all, :joins => "#{@@registration_dates_join} INNER JOIN patient ON patient.patient_id = patient_start_dates.patient_id",
                          :conditions => ["start_date >= ? AND start_date <= ? AND patient.gender = 'Male'", 
                                           @start_date, @end_date])
  end

  def women_started_on_arv_therapy
    # removed :include because it uses DISTINCT when passed to count. We don't want DISTINCT
    PatientStartDate.find(:all, :joins => "#{@@registration_dates_join} INNER JOIN patient ON patient.patient_id = patient_start_dates.patient_id",
                           :conditions => ["start_date >= ? AND start_date <= ? AND patient.gender = 'Female'", 
                                           @start_date, @end_date])
  end

  def new_pregnant_women
    PatientStartDate.find(:all, 
                                 :joins => "#{@@registration_dates_join} INNER JOIN obs ON obs.patient_id = patient_start_dates.patient_id AND obs.voided = 0",
                                 :conditions => ['start_date >= ? AND start_date <= ? AND ((obs.concept_id = ? AND obs.value_coded = ?) 
                                                  OR (obs.concept_id = ? AND obs.value_coded = ?)
                                                 )',
                                                 @start_date, @end_date, Concept.find_by_name('Referred by PMTCT').id, Concept.find_by_name('Yes').id,Concept.find_by_name('Pregnant when art was started').id, Concept.find_by_name('Yes').id
                                                ],:group => 'patient_start_dates.patient_id'
                                )
  end



  def pregnant_women
=begin
    PatientStartDate.find(:all, 
                                 :joins => "#{@@registration_dates_join} INNER JOIN obs ON obs.patient_id = patient_start_dates.patient_id AND obs.voided = 0",
                                 :conditions => ['start_date >= ? AND start_date <= ? AND obs.concept_id = ? OR (obs.concept_id = ? AND obs.value_coded = ? AND DATEDIFF(DATE(obs.obs_datetime), start_date) <= ?)',
                                                 @start_date, @end_date,
                                                 Concept.find_by_name('Referred by PMTCT').id,
                                                 Concept.find_by_name('Pregnant').id,
                                                 Concept.find_by_name('Yes').id, 30
                                                ],
                                 :group => 'patient_start_dates.patient_id'
                                )
=end
    yes_concept_id = Concept.find_by_name('Yes').id
    PatientStartDate.find(:all,
                        :joins => "#{@@registration_dates_join} INNER JOIN obs ON obs.patient_id = patient_start_dates.patient_id
                                   AND obs.voided = 0",
                        :conditions => ['start_date >= ? AND start_date <= ? AND ((obs.concept_id = ?
                                   AND obs.value_coded = ? AND DATEDIFF(DATE(obs.obs_datetime), start_date) >= ?
                                   AND DATEDIFF(DATE(obs.obs_datetime), start_date) <= ?) OR (obs.concept_id = ?
                                   AND obs.value_coded =?) OR (obs.concept_id = ? AND obs.value_coded = ?))', @start_date, @end_date,
                                        Concept.find_by_name('Pregnant').id, yes_concept_id, 0, 30,
                                        Concept.find_by_name('Referred by PMTCT').id, yes_concept_id,
                                        Concept.find_by_name('Pregnant when art was started').id, yes_concept_id],
                        :group => 'patient_start_dates.patient_id'
    )
  end

  def non_pregnant_women
    self.women_started_on_arv_therapy - self.pregnant_women
  end

  def adults_started_on_arv_therapy
    PatientStartDate.find(:all, :joins => "#{@@registration_dates_join} INNER JOIN patient ON patient.patient_id = patient_start_dates.patient_id", :conditions => ["start_date >= ? AND start_date <= ? AND TRUNCATE(DATEDIFF(start_date, birthdate)/365,0) >= ?", @start_date, @end_date, 15])
  end

  def children_started_on_arv_therapy
    PatientStartDate.find(:all, :joins => "#{@@registration_dates_join} INNER JOIN patient ON patient.patient_id = patient_start_dates.patient_id", 
                           :conditions => ["start_date >= ? AND start_date <= ? AND  TRUNCATE(DATEDIFF(start_date, birthdate)/365,1) >=  ? AND TRUNCATE(DATEDIFF(start_date, birthdate)/365,0) < ?",
                                           @start_date, @end_date, 1.5, 15])
  end

  def infants_started_on_arv_therapy
    PatientStartDate.find(:all, :joins => "#{@@registration_dates_join} INNER JOIN patient ON patient.patient_id = patient_start_dates.patient_id", 
                           :conditions => ["start_date >= ? AND start_date <= ? AND TRUNCATE(DATEDIFF(start_date, birthdate)/365,1) < ?",
                                           @start_date, @end_date, 1.5])
  end

  def transfer_ins_started_on_arv_therapy
    PatientStartDate.find(:all, :joins => "#{@@registration_dates_join} INNER JOIN patient ON patient.patient_id = patient_start_dates.patient_id INNER JOIN obs ON obs.patient_id = patient.patient_id AND obs.voided = 0", 
                                 :conditions => ["start_date >= ? AND start_date <= ? AND obs.concept_id = ? AND value_coded = ?", 
                                           @start_date, @end_date, 
                                           Concept.find_by_name('Ever registered at ART clinic').id, 
                                           Concept.find_by_name('Yes').id])
  end

  def new_patients
    self.patients_started_on_arv_therapy - self.transfer_ins_started_on_arv_therapy
  end

  def occupations
    occupation = PatientIdentifierType.find_by_name("Occupation").patient_identifier_type_id
    occupation_hash = Hash.new(0)
    PatientStartDate.find(:all,
      :joins => 
        "#{@@registration_dates_join} 
         INNER JOIN patient_identifier ON \
           patient_identifier.patient_id = patient_start_dates.patient_id AND \
           patient_identifier.voided = 0 AND \
           patient_identifier.identifier_type = #{occupation}",
      :conditions => ["start_date >= ? AND start_date <= ?", @start_date, @end_date],
      :group => "identifier",
      :order => "patient_identifier.date_created DESC",
      :select => "identifier, count(*) as count").map {|r| 
        identifier = r.identifier.downcase
        identifier = 'soldier/police' if identifier =~ /police|soldier/
        identifier = 'business' if identifier =~ /business/ # TODO: do this for all other occupations
        identifier = 'healthcare worker' if identifier =~ /health|nurse|doctor|clinical officer|patient attendant/
        identifier = 'farmer' if identifier =~ /farmer/ # TODO: do this for all other occupations
        identifier = 'teacher' if identifier =~ /teacher/ # TODO: do this for all other occupations
        identifier = 'student' if identifier =~ /student|pupil/ # TODO: do this for all other occupations
        identifier = 'housewife' if identifier =~ /housewife/ # TODO: do this for all other occupations
        occupation_hash[identifier] += r.count.to_i

      }
    occupation_hash
  end

# Reason for starting
# WHO Stage III
# WHO Stage IV
# CD4 Count
# Lymphocyte count below threshold with WHO Stage 2
# KS

# TB <= Staging
# EPTB <= Staging
# Active PTB <= Staging
# PTB within the past 2 years <= Staging
# Pregnant women started on ART for PMTCT <= Staging
   
  #TODO: This should be integrated into outcomes
  def outcomes(start_date=@start_date, end_date=@end_date, outcome_end_date=@end_date, min_age=nil, max_age=nil)
    start_date = "#{start_date} 00:00:00" unless start_date == @start_date
    end_date = "#{end_date} 23:59:59" unless end_date == @end_date
    outcome_end_date = "#{outcome_end_date} 23:59:59" unless outcome_end_date == @end_date

    outcome_hash = Hash.new(0)
    conditions = ["start_date >= ? AND start_date <= ?", start_date, end_date]
    if min_age or max_age
      min_age = 0 unless min_age
      max_age = 999 unless max_age # TODO: Should this be something like MAX(age_at_initiation) ?
      #conditions = ["start_date >= ? AND start_date <= ? AND 
      #               ROUND(DATEDIFF(start_date, birthdate)/30) >= ? AND 
      #               ROUND(DATEDIFF(start_date, birthdate)/30) <= ?", 
      #               start_date, end_date, min_age*12, max_age*12]
      conditions = ["start_date >= ? AND start_date <= ? AND 
                     TRUNCATE(DATEDIFF(start_date, birthdate)/365,0) >= ? AND
                     TRUNCATE(DATEDIFF(start_date, birthdate)/365,0) <= ?",
                     start_date, end_date, min_age, max_age]
    end
    # This find is difficult because you need to join in the outcomes, however
    # you want to get the most recent outcome for the period, meaning you have
    # to group and sort and filter all within the join
    #
    # self.ourcomes specific outcome_join to use Start and Outcome End Dates from Survival Analysis
    outcome_join = "INNER JOIN ( \
           SELECT * FROM ( \
             SELECT * \
             FROM patient_historical_outcomes \
             INNER JOIN ( \
               SELECT concept_id, 0 AS sort_weight FROM concept WHERE concept_id = 322 \
               UNION SELECT concept_id, 1 AS sort_weight FROM concept WHERE concept_id = 374 \
               UNION SELECT concept_id, 2 AS sort_weight FROM concept WHERE concept_id = 383 \
               UNION SELECT concept_id, 3 AS sort_weight FROM concept WHERE concept_id = 325 \
               UNION SELECT concept_id, 4 AS sort_weight FROM concept WHERE concept_id = 386 \
               UNION SELECT concept_id, 5 AS sort_weight FROM concept WHERE concept_id = 373 \
               UNION SELECT concept_id, 6 AS sort_weight FROM concept WHERE concept_id = 324 \
             ) AS ordered_outcomes ON ordered_outcomes.concept_id = patient_historical_outcomes.outcome_concept_id \
             WHERE outcome_date >= '#{start_date}' AND outcome_date <= '#{outcome_end_date}' \
             ORDER BY DATE(outcome_date) DESC, sort_weight \
           ) as t GROUP BY patient_id \
        ) as outcome ON outcome.patient_id = patient_start_dates.patient_id"
    PatientStartDate.find(:all,
      :joins => "#{outcome_join} #{@@registration_dates_join} INNER JOIN patient ON patient.patient_id = patient_start_dates.patient_id",
      :conditions => conditions,
      :group => "outcome_concept_id",
      :select => "outcome_concept_id, count(*) as count").map {|r| outcome_hash[r.outcome_concept_id.to_i] = r.count.to_i }
    outcome_hash
  end
   
  def regimens
    on_art_concept_id = Concept.find_by_name("On ART").id
    regimen_hash = Hash.new(0)
    # This find is difficult because you need to join in the outcomes and 
    # regimens, however you want to get the most recent outcome or regimen for 
    # the period, meaning you have to group and sort and filter all within the 
    # join. We use a left join for regimens so that unknown regimens show as 
    # NULL. 
    PatientStartDate.find(:all,
      :joins => 
        "LEFT JOIN ( \
            SELECT * FROM ( \
              SELECT patient_historical_regimens.regimen_concept_id, patient_historical_regimens.patient_id AS pid \
              FROM patient_historical_regimens \
              WHERE dispensed_date >= '#{@start_date}' AND dispensed_date <= '#{@end_date}' \
              ORDER BY dispensed_date DESC \
            ) as ordered_regimens \
            GROUP BY ordered_regimens.pid \
         ) as last_regimen ON last_regimen.pid = patient_start_dates.patient_id \
        
        #{@outcome_join} #{@@registration_dates_join}",
      :conditions => ["start_date >= ? AND start_date <= ? and start_date = start_date AND outcome_concept_id = ?", @start_date, @end_date, 324],
      :group => "regimen_concept_id",
      :select => "regimen_concept_id, count(*) as count").map {|r| regimen_hash[r.regimen_concept_id.to_i] = r.count.to_i }
    regimen_hash
  end
   
  def side_effects
    side_effects_hash = {}
    [
#     "Is able to walk unaided",
#     "Is at work/school",
     "Peripheral neuropathy", 
     "Leg pain / numbness",
     "Hepatitis", 
     "Jaundice",
     "Skin rash",
     "Lipodystrophy",
     "Lactic acidosis",
     "Anaemia",
     "Other symptom", 
     "Other side effect"].map {|symptom|  
      concept_id = Concept.find_by_name(symptom).id 
      side_effects_hash[concept_id] = count_last_observations_for([concept_id])
    }

    total_side_effects =
      ["Peripheral neuropathy", 
       "Hepatitis", 
       "Skin rash"].map {|symptom|  
        concept_id = Concept.find_by_name(symptom).id 
      }
       
    side_effects_hash['side_effects_patients_ever'] = count_observations_for(total_side_effects)    
    side_effects_hash['side_effects_patients'] = count_last_observations_for(total_side_effects)    
    side_effects_hash    
  end
  
  # Adults on 1st line regimen with pill count done in the last month of the quarter
  # We implement this as last month of treatment in this period
  # Later join this so it is first line reg

  def side_effect_patients
    find_patients_with_last_observation([91, 416, 92, 419, 93])
  end

  def transferred_out_patients(outcome_end_date=@end_date,min_age=nil, max_age=nil)
    if min_age and max_age
      patients_with_outcomes('Transfer out,Transfer Out(With Transfer Note),Transfer Out(Without Transfer Note)'.split(","),
                           outcome_end_date, min_age, max_age)
    else
      patients_with_outcomes('Transfer out,Transfer Out(With Transfer Note),Transfer Out(Without Transfer Note)'.split(","), outcome_end_date)
    end
  end
 
   def adults_on_first_line_with_pill_count
    ## TODO, not limiting to first line
     Patient.find(:all,                                              
      :joins => 
        "INNER JOIN patient_whole_tablets_remaining_and_brought ON patient_whole_tablets_remaining_and_brought.patient_id = patient.patient_id
        #{@@age_at_initiation_join_for_pills}  
        INNER JOIN patient_start_dates \
           ON start_date >= '#{@start_date}' AND start_date <= '#{@end_date}' AND \
              patient_start_dates.patient_id = patient_whole_tablets_remaining_and_brought.patient_id AND \
              patient_start_dates.age_at_initiation >= 15
         INNER JOIN patient_historical_regimens ON patient.patient_id = patient_historical_regimens.patient_id AND patient_historical_regimens.regimen_concept_id = 450 AND dispensed_date >= '#{@start_date}' AND dispensed_date <= '#{@end_date}' 
         
        #{@outcome_join}
        #{@@registration_dates_join}",
      :conditions => ["visit_date >= ? AND visit_date <= ? AND outcome_concept_id = ?", @start_date, @end_date, 324],      
      :group => "patient_whole_tablets_remaining_and_brought.patient_id")
  end

  # With pill count in the last month of the quarter at 8 or less

  def adults_on_first_line_with_pill_count_with_eight_or_less
    ## TODO, not limiting to first line
    Patient.find(:all,                                              
      :joins => 
        "INNER JOIN patient_whole_tablets_remaining_and_brought \
          ON patient_whole_tablets_remaining_and_brought.patient_id = patient.patient_id
        #{@@age_at_initiation_join_for_pills}  
        INNER JOIN patient_start_dates \
           ON start_date >= '#{@start_date}' AND start_date <= '#{@end_date}' AND \
              patient_start_dates.patient_id = patient_whole_tablets_remaining_and_brought.patient_id AND \
              patient_start_dates.age_at_initiation >= 15
         INNER JOIN patient_historical_regimens ON patient.patient_id = patient_historical_regimens.patient_id AND patient_historical_regimens.regimen_concept_id = 450 AND dispensed_date >= '#{@start_date}' AND dispensed_date <= '#{@end_date}' 
        #{@outcome_join}
        #{@@registration_dates_join}",
      :conditions => ["visit_date >= ? AND visit_date <= ? AND total_remaining < 8 AND outcome_concept_id = ?", 
                      @start_date, @end_date, 324],      
      :group => "patient_whole_tablets_remaining_and_brought.patient_id")
  end
  
  def death_dates
    # Removed this from first month because some people died before they were registered at LLH and MPC
    # outcome_date >= start_date AND 
    first_month = PatientStartDate.count(:include => [:patient], 
      :joins => "#{@outcome_join} #{@@registration_dates_join}",
      :conditions => [" \
      start_date >= ? AND \
      start_date <= ? AND \
      start_date = start_date AND \
      outcome_date < DATE_ADD(start_date, INTERVAL 1 MONTH) AND \
      outcome_concept_id = ?", @start_date, @end_date, 322])

    second_month = PatientStartDate.count(:include => [:patient], 
      :joins => "#{@outcome_join} #{@@registration_dates_join}",
      :conditions => [" \
      start_date >= ? AND \
      start_date <= ? AND \
      start_date = start_date AND \
      outcome_date >= DATE_ADD(start_date, INTERVAL 1 MONTH) AND \
      outcome_date < DATE_ADD(start_date, INTERVAL 2 MONTH) AND \
      outcome_concept_id = ?", 
      @start_date, @end_date, 322])

    third_month = PatientStartDate.count(:include => [:patient], 
      :joins => "#{@outcome_join} #{@@registration_dates_join}",
      :conditions => [" \
      start_date >= ? AND \
      start_date <= ? AND \
      start_date = start_date AND \
      outcome_date >= DATE_ADD(start_date, INTERVAL 2 MONTH) AND \
      outcome_date < DATE_ADD(start_date, INTERVAL 3 MONTH) AND \
      outcome_concept_id = ?", @start_date, @end_date, 322])

    after_third_month = PatientStartDate.count(:include => [:patient], 
      :joins => "#{@outcome_join} #{@@registration_dates_join}",
      :conditions => [" \
      start_date >= ? AND \
      start_date <= ? AND \
      start_date = start_date AND \
      outcome_date >= DATE_ADD(start_date, INTERVAL 3 MONTH) AND \
      outcome_date IS NOT NULL AND \
      outcome_concept_id = ?", @start_date, @end_date, 322])
  
    [first_month, second_month, third_month, after_third_month]
  end
 
  def find_all_dead_patients(field)
    # Removed this from first month because some people died before they were registered at LLH and MPC
    # outcome_date >= start_date AND 
    if field == 'died_1st_month'
      dead_patients_list = Patient.find(:all,
        :joins => "INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id #{@outcome_join} #{@@registration_dates_join}",
        :conditions => [" \
        start_date >= ? AND \
        start_date <= ? AND \
        start_date = start_date AND \
        outcome_date < DATE_ADD(start_date, INTERVAL 1 MONTH) AND \
        outcome_concept_id = ?", @start_date, @end_date, 322])
    elsif field == 'died_2nd_month'
      dead_patients_list = Patient.find(:all, 
        :joins => " INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id #{@outcome_join} #{@@registration_dates_join}",
        :conditions => [" \
        start_date >= ? AND \
        start_date <= ? AND \
        start_date = start_date AND \
        outcome_date >= DATE_ADD(start_date, INTERVAL 1 MONTH) AND \
        outcome_date < DATE_ADD(start_date, INTERVAL 2 MONTH) AND \
        outcome_concept_id = ?", 
        @start_date, @end_date, 322])
    elsif field == 'died_3rd_month'
      dead_patients_list = Patient.find(:all, 
        :joins => "INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id #{@outcome_join} #{@@registration_dates_join}",
        :conditions => [" \
        start_date >= ? AND \
        start_date <= ? AND \
        start_date = start_date AND \
        outcome_date >= DATE_ADD(start_date, INTERVAL 2 MONTH) AND \
        outcome_date < DATE_ADD(start_date, INTERVAL 3 MONTH) AND \
        outcome_concept_id = ?", @start_date, @end_date, 322])
    elsif field == 'died_after_3rd_month'
      dead_patients_list = Patient.find(:all, 
        :joins => "INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id #{@outcome_join} #{@@registration_dates_join}",
        :conditions => [" \
        start_date >= ? AND \
        start_date <= ? AND \
        start_date = start_date AND \
        outcome_date >= DATE_ADD(start_date, INTERVAL 3 MONTH) AND \
        outcome_date IS NOT NULL AND \
        outcome_concept_id = ?", @start_date, @end_date, 322])
    end
    dead_patients_list
  end

  def start_reasons
    patients = Patient.find(:all, 
                            :joins => "INNER JOIN patient_start_dates ON \
                                       patient_start_dates.patient_id = patient.patient_id
                                       #{@@registration_dates_join}",
                            :conditions => ["start_date >= ? AND start_date <= ?", 
                                             @start_date, @end_date])
    start_reasons = Hash.new(0)
    start_reasons["start_cause_EPTB"] = 0
    start_reasons["start_cause_PTB"] = 0
    start_reasons["start_cause_APTB"] = 0
    start_reasons["start_cause_KS"] = 0

    @start_reason_patient_ids = Hash.new
    
    patients.each{|patient|
      reason_for_art_eligibility = patient.reason_for_art_eligibility
      start_reason = reason_for_art_eligibility ? reason_for_art_eligibility.name : "Other"
      # start_reason = 'Other' if start_reason == 'Lymphocyte count below threshold with WHO stage 2' 

      start_reason = 'WHO Stage 4' if start_reason == 'WHO stage 4 adult' or start_reason == 'WHO stage 4 peds'
      start_reason = 'WHO Stage 3' if start_reason == 'WHO stage 3 adult' or start_reason == 'WHO stage 3 peds'
 
      start_reasons[start_reason] += 1
      load_start_reason_patient(start_reason, patient.id)

      cohort_visit_data = patient.get_cohort_visit_data(@start_date.to_date, @end_date.to_date)  
      if cohort_visit_data["Extrapulmonary tuberculosis"] == true
        start_reasons["start_cause_EPTB"] += 1
        load_start_reason_patient('start_cause_TB', patient.id)
      elsif cohort_visit_data["Pulmonary tuberculosis within the last 2 years"] == true
        start_reasons["start_cause_PTB"] += 1
        load_start_reason_patient('start_cause_TB', patient.id)
      elsif cohort_visit_data["Pulmonary tuberculosis (current)"] == true 
        start_reasons["start_cause_APTB"] += 1
        load_start_reason_patient('start_cause_TB', patient.id)
      end
      if cohort_visit_data["Kaposi's sarcoma"] == true
        start_reasons["start_cause_KS"] += 1
        load_start_reason_patient('start_cause_KS', patient.id)
      end
      pmtct_obs = patient.observations.find_by_concept_name("Referred by PMTCT").last
      if pmtct_obs and pmtct_obs.value_coded == 3
        start_reasons["pmtct_pregnant_women_on_art"] +=1
        load_start_reason_patient('pmtct_pregnant_women_on_art', patient.id)
      end
    }
    [start_reasons, @start_reason_patient_ids]
  end

  def patients_with_start_reason(reason)
    self.start_reasons[1][reason]
  end

  def regimen_types
    patients = Patient.find(:all,
      :joins => 
        "INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id
         #{@outcome_join} #{@@registration_dates_join}",
      :conditions => ["start_date >= ? AND start_date <= ? AND outcome_concept_id = ?", 
                      @start_date, @end_date, 324])

    alt_first_line_regimens = Hash.new(0) 
    regimen_types = Hash.new(0)
    regimen_breakdown = Hash.new(0)
    patients.each{|patient|
      regimen_type = patient.cohort_last_art_regimen(@start_date, @end_date)
      drug_code = patient.cohort_last_art_drug_code(@start_date, @end_date)
      if regimen_type
        regimen_types[regimen_type] += 1
        regimen_breakdown[drug_code] += 1
        alt_first_line_regimens[drug_code.upcase] += 1 if regimen_type == "ARV First line regimen alternatives"
      else
        regimen_types['Unknown'] += 1
      end
    }
    [regimen_types, regimen_breakdown, alt_first_line_regimens]
  end

   def find_all_patient_art_regimens(regimen)
    patients = Patient.find(:all, 
                            :joins => "INNER JOIN patient_start_dates ON \
                                       patient_start_dates.patient_id = patient.patient_id 
                                       #{@@registration_dates_join}",
                            :conditions => ["start_date >= ? AND start_date <= ?", 
                                             @start_date, @end_date])
    patient_ids = []
    patients.each{|patient|
      patient_ids << Patient.find(patient.id) if (patient.cohort_last_art_regimen == regimen) rescue nil 
      }
    patient_ids 
   end

  def survival_analysis(start_date=@start_date, end_date=@end_date, outcome_end_date=@end_date, min_age=nil, max_age=nil)
    # Make sure these are always dates
    start_date = start_date.to_date
    end_date = end_date.to_date
    outcome_end_date = outcome_end_date.to_date

    date_ranges = Array.new
    # TODO: Remove magic number 3. Loop til the very first quarter
    (1..4).each{ |i|
      start_date = start_date.subtract_months(12)
      start_date -= start_date.day - 1
      end_date = end_date.subtract_months(12)
      date_ranges << {:start_date => start_date, :end_date => end_date}
    }

    survival_analysis_outcomes = Array.new

    date_ranges.each_with_index{|date_range, i|
      outcomes_hash = Hash.new(0)
      all_outcomes = self.outcomes(date_range[:start_date], date_range[:end_date], outcome_end_date, min_age, max_age)

      outcomes_hash["Title"] = "#{(i+1)*12} month survival: outcomes by end of #{outcome_end_date.strftime('%B %Y')}"
      outcomes_hash["Start Date"] = date_range[:start_date]
      outcomes_hash["End Date"] = date_range[:end_date]

      survival_cohort = Reports::CohortByStartDate.new(date_range[:start_date], date_range[:end_date])
      if max_age.nil?
        outcomes_hash["Total"] = survival_cohort.patients_started_on_arv_therapy.length rescue all_outcomes.values.sum
      else
        outcomes_hash["Total"] = all_outcomes.values.sum
      end
      outcomes_hash["Unknown"] = outcomes_hash["Total"] - all_outcomes.values.sum
      outcomes_hash["outcomes"] = all_outcomes
      
      survival_analysis_outcomes << outcomes_hash 
    }
    survival_analysis_outcomes
  end

  def children_survival_analysis
    self.survival_analysis(@start_date, @end_date, @end_date, 0, 14)
  end

  # Debugger
  def patients_with_occupations(occupation)
    occupation_id = PatientIdentifierType.find_by_name("Occupation").patient_identifier_type_id
    Patient.find(:all,
      :joins => "INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id   
        INNER JOIN patient_identifier ON \
           patient_identifier.patient_id = patient_start_dates.patient_id AND \
           patient_identifier.voided = 0 AND \
           patient_identifier.identifier_type = #{occupation_id}",
      :conditions => ["start_date >= ? AND start_date <= ? AND identifier IN (?)", 
                       @start_date, @end_date, occupation],
      :order => "patient_identifier.date_created DESC")
  end

  def patients_with_outcomes(outcomes, outcome_end_date=@end_date, min_age=nil, max_age=nil)
    concept_ids = []
    outcomes.each{|name|
      concept_ids << Concept.find_by_name(name).id rescue 0
    }
    conditions = ['start_date >= ? AND start_date <= ? AND outcome.outcome_concept_id IN (?) ',
                       @start_date, @end_date, concept_ids]
    conditions = ["start_date >= ? AND start_date <= ? AND outcome.outcome_concept_id IN (?) AND age_at_initiation >= ? AND age_at_initiation <= ?",
                                                 @start_date, @end_date, concept_ids, min_age, max_age] if min_age and max_age

    Patient.find(:all,
      :joins => "INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id
                 INNER JOIN patient_historical_outcomes ON patient_historical_outcomes.patient_id = patient.patient_id
                 #{@outcome_join}",
      :conditions => conditions,
      :group => 'patient.patient_id', :order => 'patient_id'
    )
  end

  def patients_with_unknown_outcome(outcome_end_date=@end_date, min_age=nil, max_age=nil)
    if min_age and max_age
      self.patients_started_on_arv_therapy(min_age, max_age).map(&:patient_id) - self.patients_with_outcomes(
                                               ['On ART', 'Died', 'ART Stop', 'Defaulter'],
                                               outcome_end_date, min_age, max_age).map(&:patient_id) -
                                               self.transferred_out_patients(outcome_end_date, min_age, max_age).map(&:patient_id)
    else
      self.patients_started_on_arv_therapy.map(&:patient_id) - self.patients_with_outcomes(
                                               ['On ART', 'Died', 'ART Stop', 'Defaulter'],
                                               outcome_end_date).map(&:patient_id) -
                                               self.transferred_out_patients(outcome_end_date).map(&:patient_id)
    end
  end

  def find_patients_with_last_observation(concepts, field = :value_coded, values = nil)
    values ||= [
      Concept.find_by_name("Yes").concept_id, 
      Concept.find_by_name("Yes drug induced").concept_id, 
      Concept.find_by_name("Yes not drug induced").concept_id, 
      Concept.find_by_name("Yes unknown cause").concept_id]
    Patient.find(:all,
      :joins => 
        "INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id
         INNER JOIN ( \
          SELECT * FROM ( \
            SELECT * \
            FROM obs \
            INNER JOIN ( \
              SELECT * FROM ( \
                SELECT encounter.encounter_id AS eid, encounter.patient_id AS pid \
                FROM encounter \
                WHERE encounter_datetime >= '#{@start_date}' AND encounter_datetime <= '#{@end_date}' AND encounter_type = 2 \
                ORDER BY encounter_datetime DESC \
              ) as ordered_encounters \
              GROUP BY ordered_encounters.pid \
            ) as last_encounter ON last_encounter.eid = obs.encounter_id \
            WHERE obs_datetime >= '#{@start_date}' AND obs_datetime <= '#{@end_date}' AND \
              concept_id IN (#{concepts.join(',')}) AND #{field} IN (#{values.join(',')}) \
            ORDER BY obs_datetime DESC \
          ) as t GROUP BY patient_id \
        ) as observation ON observation.patient_id = patient_start_dates.patient_id \
        
        #{@outcome_join} #{@@registration_dates_join}",
      :conditions => ["start_date >= ? AND start_date <= ? AND outcome_concept_id = ?", @start_date, @end_date, 324])
  end

  def cached_cohort_values
    start_date = @start_date.to_date
    end_date = @end_date.to_date
    report_values = CohortReportFieldValue.find(:all, :conditions => ['start_date = ? AND end_date = ?', 
                                                 start_date, end_date])
    value_hash = {}
    report_values.each do |report_value|
      value_hash[report_value.short_name] = report_value.value
    end

    value_hash
  end

  def report_values
    cohort_report = self #Reports::CohortByRegistrationDate.new(@quarter_start, @quarter_end)

    cohort_values = self.cached_cohort_values 
    return cohort_values unless cohort_values.blank?

    PatientStartDate.find(:first)
    PatientRegistrationDate.find(:first)
    PatientAdherenceDate.find(:first)
    PatientPrescriptionTotal.find(:first)
    PatientWholeTabletsRemainingAndBrought.find(:first)
    PatientHistoricalOutcome.find(:first)
    PatientHistoricalRegimen.find(:first)

#    cohort_values = Hash.new(0) #Patient.empty_cohort_data_hash
    cohort_values = Patient.empty_cohort_data_hash
    cohort_values['messages'] = []

    cohort_values['all_patients'] = cohort_report.patients_started_on_arv_therapy.length
    cohort_values['male_patients'] = cohort_report.men_started_on_arv_therapy.length
    cohort_values['female_patients'] = cohort_report.women_started_on_arv_therapy.length

    cohort_values['adult_patients'] = cohort_report.adults_started_on_arv_therapy.length
    cohort_values['child_patients'] = cohort_report.children_started_on_arv_therapy.length
    cohort_values['infant_patients'] = cohort_report.infants_started_on_arv_therapy.length
    cohort_values['transfer_in_patients'] = cohort_report.transfer_ins_started_on_arv_therapy.length
    cohort_values['new_patients'] = cohort_values['all_patients'] - cohort_values['transfer_in_patients']

=begin    
    cohort_values['occupations'] = cohort_report.occupations
    total_reported_occupations =  cohort_values['occupations']['housewife'] + 
      cohort_values['occupations']['farmer'] + cohort_values['occupations']['soldier/police'] + 
      cohort_values['occupations']['teacher'] + cohort_values['occupations']['business'] + 
      cohort_values['occupations']['healthcare worker'] + cohort_values['occupations']['student']

    cohort_values['occupations']['other'] = cohort_values['all_patients'] - 
                                             total_reported_occupations
=end                                             
    # Reasons  for Starting
    # You can also use /reports/cohort_start_reasons
    start_reasons = cohort_report.start_reasons
    cohort_values['start_reasons']  = start_reasons
    cohort_values['who_stage_1_or_2_cd4'] = start_reasons[0]["CD4 Count < 250"] + start_reasons[0]['CD4 percentage < 25'] || 0
    cohort_values['who_stage_2_lymphocyte'] = start_reasons[0]["Lymphocyte count below threshold with WHO stage 2"]
    cohort_values['infants_PCR'] = start_reasons[0]["PCR Test"]
    cohort_values['infants_presumed_severe_HIV'] = start_reasons[0]["Presumed HIV Disease"]
    cohort_values['child_hiv_positive'] = start_reasons[0]["Child HIV positive"]
    cohort_values['breastfeeding_mothers'] = start_reasons[0]["Breastfeeding"]
    cohort_values['started_cause_pregnant'] = start_reasons[0]["Pregnant"]
    cohort_values['who_stage_3'] = start_reasons[0]["WHO Stage 3"] || start_reasons[0][" Stage 3"] || 0
    cohort_values['who_stage_4'] = start_reasons[0]["WHO Stage 4"] || start_reasons[0][" Stage 4"] || 0
    cohort_values['start_reason_other'] = start_reasons[0]["Other"] || 0

    cohort_values["start_cause_TB"] = start_reasons[0]['start_cause_EPTB'] +
                                       start_reasons[0]['start_cause_PTB'] +
                                       start_reasons[0]['start_cause_APTB']
    cohort_values["start_cause_KS"] = start_reasons[0]['start_cause_KS']
    cohort_values["pmtct_pregnant_women_on_art"] = cohort_report.pregnant_women.length
    cohort_values['non_pregnant_women'] = cohort_values["female_patients"] - cohort_values["pmtct_pregnant_women_on_art"]


    regimens = cohort_report.regimens
    #cohort_values['regimen_types'] = cohort_report.regimen_types
    #cohort_values['regimen_types'] = Hash.new(0)
    
    regimen_breakdown = Hash.new(0)
    regimens.map do |concept_id,number| 
      regimen_breakdown[(Concept.find(concept_id).name rescue "Other Regimen")] = number 
    end

    cohort_values['ARV First line regimen']   = regimen_breakdown['Stavudine Lamivudine Nevirapine Regimen']
    cohort_values['1st_line_alternative_ZLN'] = regimen_breakdown['Zidovudine Lamivudine Nevirapine Regimen']
    cohort_values['1st_line_alternative_SLE'] = regimen_breakdown['Stavudine Lamivudine Efavirenz Regimen'] 
    cohort_values['1st_line_alternative_ZLE'] = regimen_breakdown['Zidovudine Lamivudine Efavirenz Regimen']
    cohort_values['ARV First line regimen alternatives'] = cohort_values['1st_line_alternative_ZLN'] +
                                                            cohort_values['1st_line_alternative_SLE'] +
                                                            cohort_values['1st_line_alternative_ZLE']
    
    cohort_values['2nd_line_alternative_ZLTLR'] = regimen_breakdown['Zidovudine Lamivudine Tenofovir Lopinavir/Ritonavir Regimen']
    cohort_values['2nd_line_alternative_DALR']  = regimen_breakdown['Didanosine Abacavir Lopinavir/Ritonavir Regimen'] 
    cohort_values['ARV Second line regimen']    = cohort_values['2nd_line_alternative_ZLTLR'] + 
                                                   cohort_values['2nd_line_alternative_DALR']
    
    cohort_values['other_regimen'] = regimen_breakdown['Other Regimen']

    outcomes = cohort_report.outcomes
    cohort_values['alive_on_ART_patients']    = outcomes[Concept.find_by_name('On ART').id]
    cohort_values['dead_patients']            = outcomes[Concept.find_by_name('Died').id]
    cohort_values['defaulters']               = outcomes[Concept.find_by_name('Defaulter').id]
    cohort_values['art_stopped_patients']     = outcomes[Concept.find_by_name('ART Stop').id]
    cohort_values['transferred_out_patients'] = outcomes[Concept.find_by_name('Transfer out').id] + 
                                                 outcomes[Concept.find_by_name('Transfer Out(With Transfer Note)').id] +
                                                 outcomes[Concept.find_by_name('Transfer Out(Without Transfer Note)').id]


    side_effects = cohort_report.side_effects

    cohort_values['peripheral_neuropathy_patients'] = side_effects[Concept.find_by_name('Peripheral neuropathy').id] + 
                                                       side_effects[Concept.find_by_name('Leg pain / numbness').id]
    cohort_values['hepatitis_patients'] = side_effects[Concept.find_by_name('Hepatitis').id] + 
                                           side_effects[Concept.find_by_name('Jaundice').id]
    cohort_values['skin_rash_patients'] = side_effects[Concept.find_by_name('Skin rash').id]
    cohort_values['side_effect_patients'] = side_effects["side_effects_patients"]

    cohort_values['adults_on_1st_line_with_pill_count'] = cohort_report.adults_on_first_line_with_pill_count.length
    cohort_values['patients_with_pill_count_less_than_eight'] = cohort_report.adults_on_first_line_with_pill_count_with_eight_or_less.length
    cohort_values['adherent_patients'] = cohort_report.adherent_patients.length

    death_dates = cohort_report.death_dates
    cohort_values['died_1st_month'] = death_dates[0]
    cohort_values['died_2nd_month'] = death_dates[1]
    cohort_values['died_3rd_month'] = death_dates[2]
    cohort_values['died_after_3rd_month'] = death_dates[3]
    
    cohort_values    
  end

  def names_to_short_names
    fields = CohortReportField.find(:all)
    names_to_codes = {}
    fields.each do |field|
      names_to_codes[field.name] = field.short_name
    end

    names_to_codes
  end

  def quarterly?
    start_date = @start_date.to_date
    end_date = @end_date.to_date
    quarter_end_days = {'01-01' => '03-31', '04-01' => '06-30', 
                        '07-01' => '09-30', '10-01' => '12-31'}

    puts start_date.strftime('%m-%d')
    return false if quarter_end_days[start_date.strftime('%m-%d')].nil?

    quarter_end_days[start_date.strftime('%m-%d')] == end_date.strftime('%m-%d')
  end

  def save(values=nil)
    start_date = @start_date.to_date
    end_date = @end_date.to_date
    values = self.report_values unless values
    values.each_pair do |key, value|
      next if value.class != Fixnum
      report_field = CohortReportFieldValue.find(:first, :conditions => ['start_date = ? AND end_date = ? AND short_name = ?',
                                                                         start_date, end_date, key])

      report_field = CohortReportFieldValue.new unless report_field
      report_field.start_date = @start_date
      report_field.end_date = @end_date
      report_field.short_name = key
      report_field.value = value
      report_field.save
    end
  end

  def clear_cache
    start_date = @start_date.to_date
    end_date = @end_date.to_date
    CohortReportFieldValue.delete_all(['start_date = ? AND end_date = ?', 
                                                       start_date, end_date])
  end

  def short_name_to_method #(short_name)
    {
#     '1st_line_alternative_SLE' => '1st_line_alternative_SLE',
#     '1st_line_alternative_ZLE' => '1st_line_alternative_ZLE',
#     '1st_line_alternative_ZLN' => '1st_line_alternative_ZLN',
#     '2nd_line_alternative_DALR' => '2nd_line_alternative_DALR',
#     '2nd_line_alternative_ZLTLR' => '2nd_line_alternative_ZLTLR',
     'adults_on_1st_line_with_pill_count' => 'adults_on_first_line_with_pill_count',
     'alive_on_ART_patients' => 'patients_with_outcomes,On ART',
     'art_stopped_patients' => 'patients_with_outcomes,ART Stop',
#     'ARV First line regimen' => 'ARV First line regimen',
#     'ARV First line regimen alternatives' => 'ARV First line regimen alternatives',
#     'ARV Second line regimen' => 'ARV Second line regimen',

     'dead_patients'  => 'patients_with_outcomes,Died',
     'defaulters'     => 'patients_with_outcomes,Defaulter',
     'died_1st_month' => 'find_all_dead_patients,died_1st_month',
     'died_2nd_month' => 'find_all_dead_patients,died_2nd_month',
     'died_3rd_month' => 'find_all_dead_patients,died_3rd_month',
     'died_after_3rd_month' => 'find_all_dead_patients,died_after_3rd_month',
     'unknown_outcome' => 'patients_with_unknown_outcome',

#     'other_regimen' => 'other_regimen',
     'patients_with_pill_count_less_than_eight' => 'adults_on_first_line_with_pill_count_with_eight_or_less',
     'adherent_patients' => 'adherent_patients',
     'over_adherent_patients' => 'over_adherent_patients',

     'transferred_out_patients' => 'transferred_out_patients',
     'transfer_in_patients' => 'transfer_ins_started_on_arv_therapy',
     'new_patients' => 'new_patients',
     'male_patients' => 'men_started_on_arv_therapy',
     'non_pregnant_women' => 'non_pregnant_women',
     #'pmtct_pregnant_women_on_art' => 'patients_with_start_reason,pmtct_pregnant_women_on_art',
     'pmtct_pregnant_women_on_art' => 'pregnant_women',
     'adult_patients' => 'adults_started_on_arv_therapy',
     'child_patients' => 'children_started_on_arv_therapy',
     'infant_patients' => 'infants_started_on_arv_therapy',
     'infants_presumed_severe_HIV' => 'patients_with_start_reason,infants_presumed_severe_HIV',
     'child_hiv_positive' => 'patients_with_start_reason,Child HIV positive',
     'breastfeeding_mothers' => 'patients_with_start_reason,Breastfeeding',
     'started_cause_pregnant' => 'patients_with_start_reason,Pregnant',
     'infants_PCR' => 'patients_with_start_reason,infants_PCR',
     'who_stage_1_or_2_cd4' => 'patients_with_start_reason,CD4 Count < 250',
     'who_stage_2_lymphocyte' => 'patients_with_start_reason,who_stage_2_lymphocyte',
     'who_stage_3' => 'patients_with_start_reason,WHO Stage 3',
     'who_stage_4' => 'patients_with_start_reason,WHO Stage 4',

     'side_effect_patients' => 'side_effect_patients',
     'start_reason_other' => 'patients_with_start_reason,Other',
     'start_cause_TB' => 'patients_with_start_reason,start_cause_TB',
     'start_cause_KS' => 'patients_with_start_reason,start_cause_KS',
     'all_patients' => 'patients_started_on_arv_therapy',

     'arv_number_range' => 'arv_number_range',
     'not_in_arv_number_range' => 'not_in_arv_number_range',
     'dispensations_without_prescriptions' => 'dispensations_without_prescriptions',
     'prescriptions_without_dispensations' => 'prescriptions_without_dispensations'
    }
  end

  def arv_number_range
    min_arv_number = PatientRegistrationDate.find(:all,
                                 :joins => 'INNER JOIN patient_identifier ON
      patient_identifier.patient_id = patient_start_dates.patient_id AND
      patient_identifier.identifier_type = 18 AND patient_identifier.voided = 0',
                                 :conditions => ["start_date >= ? AND start_date <= ?", @start_date, @end_date],
                                 :order => 'CAST(SUBSTR(identifier,4) AS UNSIGNED)', :limit => 1)
    max_arv_number = PatientRegistrationDate.find(:all,
                                 :joins => 'INNER JOIN patient_identifier ON
      patient_identifier.patient_id = patient_start_dates.patient_id AND
      patient_identifier.identifier_type = 18 AND patient_identifier.voided = 0',
                                 :conditions => ["start_date >= ? AND start_date <= ?", @start_date, @end_date],
                                 :order => 'CAST(SUBSTR(identifier,4) AS UNSIGNED) DESC', :limit => 1)
    [min_arv_number.first, max_arv_number.first]
  end

  def not_in_arv_number_range(min, max)
    PatientRegistrationDate.find(:all,
                                 :joins => 'INNER JOIN patient_identifier ON
      patient_identifier.patient_id = patient_start_dates.patient_id AND
      patient_identifier.identifier_type = 18 AND patient_identifier.voided = 0',
                                 :conditions => ["start_date >= ? AND start_date <= ? AND CAST(SUBSTR(identifier,4) AS UNSIGNED) NOT BETWEEN ? AND ?",
                                                 @start_date, @end_date, min.to_i, max.to_i],
                                 :order => 'CAST(SUBSTR(identifier,4) AS UNSIGNED)')
  end

  def in_arv_number_range(min, max)
    Patient.find(:all,
                 :joins => 'INNER JOIN patient_start_dates ON patient_start_dates.patient_id = patient.patient_id
                 INNER JOIN patient_identifier ON
                 patient_identifier.patient_id = patient_start_dates.patient_id AND
                 patient_identifier.identifier_type = 18 AND patient_identifier.voided = 0',
                                 :conditions => ["(start_date < ? OR start_date > ?) AND CAST(SUBSTR(identifier,4) AS UNSIGNED) BETWEEN ? AND ?",
                                                 @start_date, @end_date, min.to_i, max.to_i],
                                 :order => 'CAST(SUBSTR(identifier,4) AS UNSIGNED)')
  end

  def missing_dispensations
    patients = Patient.find_by_sql ["
      SELECT patient_id, DATE(p.prescription_datetime) AS visit_date, p.drug_id FROM patient_prescriptions p
        WHERE prescription_datetime >= ? AND prescription_datetime <= ? AND
        NOT EXISTS (
          SELECT * FROM orders
            INNER JOIN encounter USING(encounter_id)
            INNER JOIN drug_order USING(order_id)
          WHERE patient_id = p.patient_id AND orders.voided = 0 AND
                DATE(encounter_datetime) = DATE(p.prescription_datetime) AND
                p.drug_id = drug_order.drug_inventory_id
        )
        ORDER BY p.prescription_datetime DESC ", @start_date, @end_date]
    patient_data = {}
    patients.each do |patient|
      patient_data[patient.patient_id] = [] unless patient_data[patient.patient_id]
      patient_data[patient.id] << {patient.visit_date => patient.drug_id}
    end

    patient_data
  end

  def missing_prescriptions
    patients = Patient.find_by_sql ["
      SELECT encounter.patient_id, DATE(encounter_datetime) AS visit_date,
             drug_order.drug_inventory_id AS drug_id
        FROM orders
        INNER JOIN encounter USING(encounter_id)
        INNER JOIN drug_order USING(order_id)
        INNER JOIN drug ON drug.drug_id = drug_order.drug_inventory_id
        INNER JOIN concept_set ON concept_set.concept_id = drug.concept_id
        WHERE encounter_datetime >= ? AND
              encounter_datetime <= ? AND
              concept_set.concept_set = 460 AND
              orders.voided = 0 AND
          NOT EXISTS (
          SELECT patient_id, DATE(p.prescription_datetime) AS visit_date, p.drug_id
            FROM patient_prescriptions p
            WHERE encounter.patient_id = p.patient_id  AND
                DATE(encounter_datetime) = DATE(p.prescription_datetime) AND
                p.drug_id = drug_order.drug_inventory_id
          )
        ORDER BY encounter_datetime DESC", @start_date, @end_date]
    patient_data = {}
    patients.each do |patient|
      patient_data[patient.patient_id] = [] unless patient_data[patient.patient_id]
      patient_data[patient.id] << {patient.visit_date => patient.drug_id}
    end

    patient_data
  end

  def patients_with_multiple_start_reasons
    patients = Patient.find(:all,
                           :joins => "INNER JOIN patient_start_dates ON \
                                      patient_start_dates.patient_id = patient.patient_id
                                      INNER JOIN encounter on encounter.patient_id = patient.patient_id \
                                      INNER JOIN obs on encounter.encounter_id = obs.encounter_id AND \
                                      encounter.encounter_type = #{EncounterType.find_by_name("HIV Staging").id}",
                           :conditions => ["start_date >= ? AND start_date <= ? AND obs.voided=0",@start_date, @end_date],
                           :group => 'patient.patient_id HAVING COUNT(encounter.encounter_id) > 1')
    patient_start_reasons = {}

    patients.each{|p|
      hiv_encounters = p.encounters.find_by_type_name("HIV Staging")
      patient_start_reasons[p.patient_id] = []
      hiv_encounters.each{|enc|
	#next if enc.

        next if enc.observations.first.voided == true rescue nil
#	created_date = {}
#	created_date[enc.date_created.strftime("%Y-%m-%d %H:%M:%S")] = enc.reason_for_starting_art(enc.date_created).name rescue 'None'
#	next if created_date[enc.date_created.strftime("%Y-%m-%d %H:%M:%S")] == 'None'
        start_reason = {}
        start_reason[enc.encounter_datetime.strftime("%Y-%m-%d")] = "#{enc.date_created.strftime("%Y-%m-%d %H:%M:%S")}--#{enc.reason_for_starting_art(enc.encounter_datetime).name}" rescue 'None'
        next if start_reason[enc.encounter_datetime.strftime("%Y-%m-%d")] == 'None'
        patient_start_reasons[p.patient_id] << start_reason
      }
    }
    patient_start_reasons.delete_if{|key, value| value.length < 2 }
    return patient_start_reasons

  end

  def adherent_patients
    self.patients_with_adherence
  end

  def over_adherent_patients
    self.patients_with_adherence(106, 999999999)
  end

  def under_adherent_patients
    self.patients_with_adherence(0, 94)
  end

  def patients_with_adherence(min=95, max=105)
    Patient.find(:all,
                 :joins => "INNER JOIN patient_start_dates on patient_start_dates.patient_id = patient.patient_id \
                           INNER JOIN (
                    SELECT r.patient_id, r.visit_date, (
                      SELECT visit_date FROM patient_adherence_rates t
                      WHERE patient_id = r.patient_id AND visit_date <= '#{@end_date.to_date}'
                      ORDER BY visit_date DESC
                      LIMIT 1
                    ) AS latest_date, r.adherence_rate
                    FROM patient_adherence_rates r
                    HAVING visit_date = latest_date AND adherence_rate BETWEEN #{min} AND #{max}
                    ) AS adherent_patients ON patient_start_dates.patient_id = adherent_patients.patient_id AND
                    start_date BETWEEN '#{@start_date}' AND '#{@end_date}'",
                 :group => 'patient_start_dates.patient_id'
                )
  end


private

  # Checking for the number of patients that have value as their most recent
  # observation for the given set of concept ids
  def count_observations_for(concepts, field = :value_coded, values = nil)
    values ||= [
      Concept.find_by_name("Yes").concept_id, 
      Concept.find_by_name("Yes drug induced").concept_id, 
      Concept.find_by_name("Yes not drug induced").concept_id, 
      Concept.find_by_name("Yes unknown cause").concept_id]
    PatientStartDate.count(
      :joins => 
        "INNER JOIN ( \
          SELECT * FROM (
            SELECT * \
            FROM obs \
            WHERE obs_datetime >= '#{@start_date}' AND obs_datetime <= '#{@end_date}' AND \
              concept_id IN (#{concepts.join(',')}) AND #{field} IN (#{values.join(',')}) \
            ORDER BY obs_datetime DESC \
          ) as t GROUP BY patient_id \
        ) as observation ON observation.patient_id = patient_start_dates.patient_id
        
        #{@outcome_join} #{@@registration_dates_join}",
      :conditions => ["start_date >= ? AND start_date <= ? AND outcome_concept_id = ?", @start_date, @end_date, 324])
  end
  
  # Checking for the number of patients that have value as their most recent
  # observation for the given set of concept ids
  def count_last_observations_for(concepts, field = :value_coded, values = nil)
    values ||= [
      Concept.find_by_name("Yes").concept_id, 
      Concept.find_by_name("Yes drug induced").concept_id, 
      Concept.find_by_name("Yes not drug induced").concept_id, 
      Concept.find_by_name("Yes unknown cause").concept_id]
    PatientStartDate.count(
      :joins => 
        "INNER JOIN ( \
          SELECT * FROM (
            SELECT * \
            FROM obs \
            INNER JOIN ( \
              SELECT * FROM ( \
                SELECT encounter.encounter_id AS eid, encounter.patient_id AS pid \
                FROM encounter \
                WHERE encounter_datetime >= '#{@start_date}' AND encounter_datetime <= '#{@end_date}' AND encounter_type = 2 \
                ORDER BY encounter_datetime DESC \
              ) as ordered_encounters \
              GROUP BY ordered_encounters.pid \
            ) as last_encounter ON last_encounter.eid = obs.encounter_id \
            WHERE obs_datetime >= '#{@start_date}' AND obs_datetime <= '#{@end_date}' AND \
              concept_id IN (#{concepts.join(',')}) AND #{field} IN (#{values.join(',')}) \
            ORDER BY obs_datetime DESC \
          ) as t GROUP BY patient_id \
        ) as observation ON observation.patient_id = patient_start_dates.patient_id \
        
        #{@outcome_join} #{@@registration_dates_join}",
      :conditions => ["start_date >= ? AND start_date <= ? AND outcome_concept_id = ?", @start_date, @end_date, 324])
  end
  

  def load_start_reason_patient(reason, patient_id)
    @start_reason_patient_ids[reason] = [] unless @start_reason_patient_ids[reason]
    @start_reason_patient_ids[reason] << patient_id
  end
 
end
