require "enumerator"

class Patient < OpenMRS
  set_table_name "patient"
  set_primary_key "patient_id"

#------------------------------------------------------------------------------
# REFACTOR   
#------------------------------------------------------------------------------
# Everything above this line is good.  

  has_many :observations, :foreign_key => :patient_id do
    def find_by_concept_id(concept_id)
      find(:all, :conditions => ["voided = 0 and concept_id = ?", concept_id])
    end
    def find_by_concept_name(concept_name)
      find(:all, :conditions => ["voided = 0 and concept_id = ?", Concept.find_by_name(concept_name).id],:order => "obs_datetime ASC")
    end
    def find_first_by_concept_name(concept_name)
      find(:first, :conditions => ["voided = 0 and concept_id = ?", Concept.find_by_name(concept_name).id], :order => "obs_datetime")
    end
    def find_last_by_concept_name(concept_name)
      find(:first, :conditions => ["voided = 0 and concept_id = ?", Concept.find_by_name(concept_name).id], :order => "obs_datetime DESC")
    end
    
    def find_by_concept_name_on_date(concept_name,date)
      find(:all, :conditions => ["voided = 0 AND concept_id = ? AND DATE(obs_datetime) = ?", Concept.find_by_name(concept_name).id, date], :order => "obs_datetime")
    end
    def find_first_by_concept_name_on_date(concept_name,date)
      find(:first, :conditions => ["voided = 0 and concept_id = ? AND DATE(obs_datetime) = ?", Concept.find_by_name(concept_name).id, date], :order => "obs_datetime")
    end
    def find_last_by_concept_name_on_date(concept_name,date)
      find(:first, :conditions => ["voided = 0 and concept_id = ? AND DATE(obs_datetime) = ?", Concept.find_by_name(concept_name).id, date], :order => "obs_datetime DESC")
    end
    def find_first_by_concept_name_on_or_after_date(concept_name,date)
      find(:first, :conditions => ["voided = 0 and concept_id = ? AND DATE(obs_datetime) >= ?", Concept.find_by_name(concept_name).id, date], :order => "obs_datetime")
    end
    def find_last_by_concept_name_on_or_before_date(concept_name,date)
      find(:first, :conditions => ["voided = 0 and concept_id = ? AND DATE(obs_datetime) <= ?", Concept.find_by_name(concept_name).id, date], :order => "obs_datetime DESC")
    end
    
    def find_last_by_concept_name_before_date(concept_name,date)
      find(:first, :conditions => ["voided = 0 and concept_id = ? AND DATE(obs_datetime) < ?", Concept.find_by_name(concept_name).id, date], :order => "obs_datetime DESC")
    end

    def find_last_by_conditions(conditions)
      # Remove voided observations
      conditions[0] = "voided = 0 AND " + conditions[0]
      find(:first, :conditions => conditions, :order => "obs_datetime DESC, date_created DESC")
    end
    def find_by_concept_name_with_result(concept_name, value_coded_concept_name)
      find(:all, :conditions => ["voided = 0 and concept_id = ? AND value_coded = ?", Concept.find_by_name(concept_name).id, Concept.find_by_name(value_coded_concept_name).id], :order => "obs_datetime DESC")
    end
  end

  has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :delete_all do
    def find_first_by_identifier_type(identifier_type)
      return find(:first, :conditions => ["patient_identifier.voided = 0 AND identifier_type = ?", identifier_type])
    end
  end
  has_many :patient_historical_regimens, :order => "dispensed_date DESC" 
  has_many :patient_regimens, :order => "dispensed_date DESC" 
  has_many :patient_names, :foreign_key => :patient_id, :dependent => :delete_all, :conditions => "patient_name.voided = 0"
  has_many :notes, :foreign_key => :patient_id
  has_many :patient_addresses, :foreign_key => :patient_id, :dependent => :delete_all
  has_many :person_attributes, :foreign_key => :person_id
  has_many :encounters, :foreign_key => :patient_id do
  
    def find_by_type_id(type_id)
      find(:all, :conditions => ["encounter_type = ?", type_id])
    end

    def find_by_type_name(type_name)
      encounter_type = EncounterType.find_by_name(type_name)
      raise "Encounter type #{type_name} does not exist" if encounter_type.nil?
      find(:all, :conditions => ["encounter_type = ?", EncounterType.find_by_name(type_name).id])
    end

    def find_last_by_type_name_before_start_art(type_name, art_start_date)
      art_start_date = Time.now if art_start_date.nil?
      encounter_type = EncounterType.find_by_name(type_name)
      raise "Encounter type #{type_name} does not exist" if encounter_type.nil?
      find(:first, 
           :joins => "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.voided = 0",
           :conditions => ["encounter.encounter_type = ? AND encounter_datetime <= ?", EncounterType.find_by_name(type_name).id, art_start_date],
           :order => "encounter.encounter_datetime DESC")
    end


    def find_by_date(encounter_date)
      find(:all, :conditions => ["DATE(encounter_datetime) = DATE(?)", encounter_date])
    end

    def find_by_type_name_and_date(type_name, encounter_date)
      find(:all, :conditions => ["DATE(encounter_datetime) = DATE(?) AND encounter_type = ?", encounter_date, EncounterType.find_by_name(type_name).id]) # Use the SQL DATE function to compare just the date part
    end
    
    def find_by_type_name_before_date(type_name, encounter_date)
      find(:all, :conditions => ["DATE(encounter_datetime) < DATE(?) AND encounter_type = ?", encounter_date, EncounterType.find_by_name(type_name).id]) # Use the SQL DATE function to compare just the date part
    end

    def find_first_by_type_name(type_name)
       find(:first,:conditions => ["encounter_type = ?", EncounterType.find_by_name(type_name).id], :order => "encounter_datetime ASC, date_created ASC")
    end

    def find_last_by_type_name(type_name)
       encounters = find(:all,:conditions => ["encounter_type = ?", EncounterType.find_by_name(type_name).id], :order => "encounter_datetime DESC, date_created DESC")
       encounters.delete_if{|e| e.voided?}
       encounters.first
    end

    def find_all_by_conditions(conditions)
      return find(:all, :conditions => conditions)
    end

    def find_last_by_conditions(conditions)
      return find(:first, :conditions => conditions, :order => "encounter_datetime DESC, date_created DESC")
    end

    def last
      return find(:first, :order => "encounter_datetime DESC, date_created DESC")
    end

  end

  has_many :people, :foreign_key => :patient_id, :dependent => :delete_all
  belongs_to :tribe, :foreign_key => :tribe_id
  belongs_to :user, :foreign_key => :user_id
  has_many :patient_programs, :foreign_key => :patient_id
  has_many :programs, :through => :patient_programs

  has_one :patient_start_date
  has_many :patient_regimens
  has_many :patient_registration_dates
  has_many :historical_outcomes, :class_name => 'PatientHistoricalOutcome' do
    
    # list patient's outcomes in reverse chronological order as of given date range
    def ordered(start_date=nil,end_date=Date.today)
      start_date = Encounter.find(:first, 
                                  :order => 'encounter_datetime'
                                 ).encounter_datetime.to_date unless start_date
      find(:all, :joins => 'INNER JOIN ( 
               SELECT concept_id, 0 AS sort_weight FROM concept WHERE concept_id = 322 
               UNION SELECT concept_id, 1 AS sort_weight FROM concept WHERE concept_id = 374 
               UNION SELECT concept_id, 2 AS sort_weight FROM concept WHERE concept_id = 383 
               UNION SELECT concept_id, 3 AS sort_weight FROM concept WHERE concept_id = 325 
               UNION SELECT concept_id, 4 AS sort_weight FROM concept WHERE concept_id = 386 
               UNION SELECT concept_id, 5 AS sort_weight FROM concept WHERE concept_id = 373 
               UNION SELECT concept_id, 6 AS sort_weight FROM concept WHERE concept_id = 324 
             ) AS ordered_outcomes ON ordered_outcomes.concept_id = patient_historical_outcomes.outcome_concept_id',
          :order => 'DATE(outcome_date) DESC, sort_weight',
          :conditions => ['DATE(outcome_date) >= ? AND DATE(outcome_date) <= ?', start_date, end_date])
    end

  end
  
  @encounter_date = nil

  def self.merge(patient_id, secondary_patient_id)
    patient = Patient.find(patient_id, :include => [:patient_identifiers, :patient_programs, :patient_names])
    secondary_patient = Patient.find(secondary_patient_id, :include => [:patient_identifiers, :patient_programs, :patient_names])

    secondary_patient.patient_identifiers.each {|r| 
      if patient.patient_identifiers.map(&:identifier).each{| i | i.upcase }.include?(r.identifier.upcase)
        r.void!("merged with patient #{patient_id}")
      else
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET patient_id = #{patient_id} 
WHERE patient_id = #{secondary_patient_id}
AND identifier_type = #{r.identifier_type}
AND identifier = "#{r.identifier}"
EOF
      end rescue r.void!("merged with patient #{patient_id}") 
    }

    secondary_patient.patient_names.each {|r| 
      if patient.patient_names.map{|pn| "#{pn.given_name.upcase} #{pn.family_name.upcase}"}.include?("#{r.given_name.upcase} #{r.family_name.upcase}")
        r.void!("merged with patient #{patient_id}")
      else
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_name SET patient_id = #{patient_id} 
WHERE patient_id = #{secondary_patient_id}
AND patient_name_id = #{r.patient_name_id}
EOF
      end rescue r.void!("merged with patient #{patient_id}")
    }
    
    secondary_patient.patient_addresses.each {|r| 
      if patient.patient_addresses.map{|pa| "#{pa.city_village.upcase}"}.include?("#{r.city_village.upcase}")
        r.void!("merged with patient #{patient_id}")
      else
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_address SET patient_id = #{patient_id} 
WHERE patient_id = #{secondary_patient_id}
AND patient_address_id = #{r.patient_name_id}
EOF
      end rescue r.void!("merged with patient #{patient_id}")
    }
    
    secondary_patient.patient_programs.each {|r| 
      if patient.patient_programs.map(&:program_id).include?(r.program_id)
        r.void!("merged with patient #{patient_id}")
      else
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_program SET patient_id = #{patient_id} 
WHERE patient_id = #{secondary_patient_id}
AND patient_program_id = #{r.patient_name_id}
EOF
      end rescue r.void!("merged with patient #{patient_id}")
    }

    secondary_patient.void!("merged with patient #{patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE person SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE patient_address SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE encounter SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE obs SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
    ActiveRecord::Base.connection.execute("UPDATE note SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
  end

  def add_program_by_name(program_name)
    self.add_programs([Program.find_by_name(program_name)])
  end

  def add_programs(programs)
    #raise programs.to_yaml
    programs.each{|program|
      patient_program = PatientProgram.new
      patient_program.patient_id = self.id
      patient_program.program_id = program.program_id
      patient_program.save
    }
  end

  # Intersect the patient's programs and the user's programs to find out what program should be used to determine the next form
  def available_programs (user = User.current_user)
    #TODO why doesn't the above .program work???
    programs = PatientProgram.find_all_by_patient_id(self.id).collect{|pp|pp.program}
    available_programs = programs & user.current_programs

#    if available_programs.length <= 0
#      raise "Patient has no programs that the current user can provide services for.\n Patient programs: #{self.programs.collect{|p|p.name}.to_yaml}\n User programs: #{User.current_user.current_programs.collect{|p|p.name}.to_yaml}" 
#    end
    available_programs
  end

  def current_encounters(date = Date.today)
    self.encounters.find(:all, :conditions => ["DATE(encounter_datetime) = DATE(?)", date], :order => "date_created DESC")
  end

  def last_encounter(date = Date.today)
    # Find the last significant (non-barcode scan) encounter
    start_date = date.strftime("%Y-%m-%d 00:00:00") 
    end_date = date.strftime("%Y-%m-%d 23:59:59")
    encounter_types = ["HIV Reception", "Height/Weight", "HIV First visit", "ART Visit", "TB Reception", "HIV Staging", "General Reception"]
    condition = encounter_types.collect{|encounter_type|
      "encounter_type = #{EncounterType.find_by_name(encounter_type).id}"
    }.join(" OR ")
    #self.encounters.find_last_by_conditions(["DATE(encounter_datetime) = DATE(?) AND (#{condition})", date])
    Encounter.find(:last,
        :conditions =>["encounter_datetime >=? AND encounter_datetime <=? AND patient_id = ? AND (#{condition})",
        start_date,end_date,self.id],:order => "encounter_datetime ASC,date_created ASC")
  end

  # Returns the name of the last patient encounter for a given day according to the 
  # patient flow regardless of the encounters' datetime
  # The order in which these encounter types are listed is different from that of next encounters
  def last_encounter_name_by_flow(date = Date.today)
    unless self.transfer_in_with_letter? 
      encounter_index_to_name = ["HIV Reception", "HIV First visit", "Height/Weight", "HIV Staging", "ART Visit", "Give drugs", "TB Reception", "General Reception"]
      encounter_name_to_index = {'HIV Reception' => 0,
                                 'HIV First visit' => 1,
                                 'Height/Weight' => 2, 
                                 'HIV Staging' => 3,
                                 'ART Visit' => 4, 
                                 'Give Drugs' => 5,
                                 'TB Reception' => 6,
                                 'General Reception' => 7
                                }
    else
      encounter_index_to_name = ["HIV Reception", "HIV First visit", "HIV Staging", "Height/Weight", "ART Visit", "Give drugs", "TB Reception", "General Reception"]
      encounter_name_to_index = {'HIV Reception' => 0,
                                 'HIV First visit' => 1,
                                 'HIV Staging' => 2,
                                 'Height/Weight' => 3, 
                                 'ART Visit' => 4, 
                                 'Give Drugs' => 5,
                                 'TB Reception' => 6,
                                 'General Reception' => 7
                                }
    end
    encounter_order_numbers = []
    self.encounters.find_by_date(date).each{|encounter|
      next if encounter.name == "General Reception" and not User.current_user.activities.include?('General Reception')
      order_number = encounter_name_to_index[encounter.name]
      encounter_order_numbers << order_number if order_number
    }
    encounter_index_to_name[encounter_order_numbers.max]
  end

  # Returns the last patient encounter for a given day according to the 
  # patient flow regardless of the encounters' datetime
  def last_encounter_by_flow(date = Date.today)
    last_encounter_name = self.last_encounter_name_by_flow(date)
    last_encounter_type = EncounterType.find_by_name(last_encounter_name)
    return self.encounters.find_last_by_conditions("encounter_type = #{last_encounter_type.id}") if last_encounter_type
    return nil
  end

  def next_forms(date = Date.today, outcome = nil)
    outcome = self.outcome unless outcome
    outcome = "" if User.current_user.activities.include?("General Reception")
    return unless outcome.name =~ /On ART|Defaulter/ rescue false
    return [] if User.current_user.activities.include?("TB Reception")
   
    user_activities = User.current_user.activities
    last_encounter = self.last_encounter(date)
    last_encounter = nil if last_encounter and last_encounter.name == "General Reception" and not user_activities.include?('General Reception')

    next_encounter_type_names = Array.new
    if last_encounter.blank?
      program_names = User.current_user.current_programs.collect{|program|program.name}
      next_encounter_type_names << "HIV Reception" if program_names.include?("HIV")
      next_encounter_type_names << "TB Reception" if program_names.include?("TB")
      next_encounter_type_names << "General Reception" if user_activities.include?('General Reception')
    else
      last_encounter = self.last_encounter_by_flow(date)
      next_encounter_type_names = last_encounter.next_encounter_types(self.available_programs(User.current_user))
    end

    # if patient is not present - always skip vitals
    if next_encounter_type_names.include?("Height/Weight")
      patient_present = self.observations.find_last_by_concept_name_on_date("Patient present",date)
      if patient_present and patient_present.value_coded != Concept.find_by_name("Yes").id
        next_encounter_type_names.delete("Height/Weight")
        next_encounter_type_names << "ART Visit"
      end
    end

    # Skip HIV first visit if they have already done it
    if next_encounter_type_names.include?("HIV First visit")
      next_encounter_type_names.delete("HIV First visit") unless self.encounters.find_by_type_name("HIV First visit").empty?
    end

    if self.reason_for_art_eligibility.blank? and not self.taken_arvs_before?
      next_encounter_type_names.delete("ART Visit")
    else
      next_encounter_type_names.delete("HIV Staging")
    end

    next_forms = Array.new
    # If there is more than one encounter_type take the first one
    if User.current_user.activities.include?("General Reception") 
      next_encounter_type_names = []
      if self.encounters.find_by_type_name_and_date("General Reception",date).blank?
        return [Form.find_by_name("General Reception")]
      end
    end

    if User.current_user.activities.include?("Pre ART visit") and next_encounter_type_names.empty? and self.reason_for_art_eligibility.blank?
      pre_art_followup = self.encounters.find_by_type_name_and_date("Pre ART visit", date).last rescue []
      if pre_art_followup.blank? and not self.taken_arvs_before?
        next_encounter_type_names << "Pre ART visit" 
      end
    end 
    
    return [] if next_encounter_type_names.empty?


    next_encounter_type_name = next_encounter_type_names.first
    next_encounter_type = EncounterType.find_by_name(next_encounter_type_name)
    raise "No encounter type named #{next_encounter_type_name}" if next_encounter_type.nil?
    forms_for_encounter = Form.find_all_by_encounter_type(next_encounter_type.id)
    next_forms <<  forms_for_encounter

    next_forms = next_forms.flatten.compact


    # Filter out forms that are age dependent and don't match the current patient
    next_forms.delete_if{|form|
      form.uri.match(/adult|child/i) and not form.uri.match(/#{self.adult_or_child}/i)
    }
# If they are a transfer in with a letter we want the receptionist to copy the staging info using the retrospective staging form
    next_forms.each{|form|
      if form.name == "HIV Staging"
        if self.transfer_in_with_letter?
          next_forms.delete(form) unless form.version == "multi_select"
        else
          next_forms.delete(form) unless form.version == GlobalProperty.find_by_property("staging_interface").property_value
        end
      end
    }

    return next_forms
    
  end

  def current_weight(date = Date.today)
    current_weight_observation = self.observations.find_last_by_concept_name_on_or_before_date("Weight",date)
    return current_weight_observation.value_numeric unless current_weight_observation.nil?
  end
  
  def current_visit_weight(date = Date.today)
    current_weight_observation = self.observations.find_last_by_concept_name_on_date("Weight",date)
    return current_weight_observation.value_numeric unless current_weight_observation.nil?
  end

  def previous_weight(date = Date.today)
    previous_weight_observation = self.observations.find_last_by_concept_name_before_date("Weight",date)
    return previous_weight_observation.value_numeric unless previous_weight_observation.nil?
  end

  def percent_weight_changed(start_date, end_date = Date.today)
    start_weight = self.observations.find_first_by_concept_name_on_or_after_date("Weight", start_date).value_numeric rescue nil
    end_weight = self.current_weight(end_date) rescue nil
    return nil  if end_weight.blank? || start_weight.blank?
    return (end_weight - start_weight)/start_weight
  end
  
  def current_height(date = Date.today)
    current_height_observation = self.observations.find_last_by_concept_name_on_or_before_date("Height",date)
    return current_height_observation.value_numeric unless current_height_observation.nil?
  end
  
  def previous_height(date = Date.today)
    previous_height_observation = self.observations.find_last_by_concept_name_before_date("Height",date)
    return previous_height_observation.value_numeric unless previous_height_observation.nil?
  end

  def current_bmi(date = Date.today)
    current_weight = self.current_weight(date)
    current_height = self.current_height(date)
    return (current_weight/(current_height**2)*10000) unless current_weight.nil? or current_height.nil?
  end

  def art_therapeutic_feeding_message(date = Date.today)
    bmi = self.current_bmi(date) 
    return if bmi.nil?
    if (bmi > 18.5)
      return ""
    elsif (bmi > 17.0)
      return "Patient needs counseling due to their low bmi"
    else
      return "Eligibile for therapeutic feeding"
    end
  end

  def outcome_date(on_date = Date.today)
    start_date = (on_date.to_date.to_s + " 00:00:00")
    end_date = (on_date.to_date.to_s + " 23:59:59")
    encounter_type = EncounterType.find_by_name("Update outcome").id

    self.encounters.find(:first,:conditions => ["encounter_datetime >='#{start_date}' 
         and encounter_datetime <='#{end_date}' and encounter_type=#{encounter_type}"],
         :order => 'encounter_datetime DESC').observations.first.obs_datetime.strftime("%d-%b-%Y") rescue nil
  end

  def outcome(on_date = Date.today)
    first_encounter_date = self.encounters.find(:first, 
                                                :order => 'encounter_datetime'
                                               ).encounter_datetime.to_date rescue nil
    self.historical_outcomes.ordered(first_encounter_date, on_date).first.concept rescue nil
  end
 
  # TODO replace all of these outcome methods with just one
  # This one returns strings - probably better to do concepts like above method 
  def outcome_status(on_date = Date.today)
    status = self.outcome(on_date).name rescue ""
  end
  
  def cohort_outcome_status(start_date=nil, end_date=nil)
    start_date = Encounter.find(:first, :order => "encounter_datetime").encounter_datetime.to_date if start_date.nil?
    end_date = Date.today if end_date.nil?

    status = self.historical_outcomes.ordered(start_date, end_date).first.concept.name rescue ''
  end

  def continue_treatment_at_current_clinic(date)
     concept_name="Continue treatment at current clinic"
     date=date.to_date
     patient_observations = Observation.find(:all,:conditions => ["concept_id=? and patient_id=? and Date(obs.obs_datetime)=?",(Concept.find_by_name(concept_name).id),self.patient_id,date],:order=>"obs.obs_datetime desc")
     return nil if patient_observations.blank?
     return Concept.find(patient_observations.first.value_coded).name rescue nil
  end
  
## DRUGS
  def drug_orders(extra_conditions='')
    DrugOrder.find(:all, 
                   :joins => 'INNER JOIN `orders` ON drug_order.order_id = orders.order_id 
                              INNER JOIN encounter ON orders.encounter_id = encounter.encounter_id', 
                   :conditions => ['encounter.patient_id = ? AND orders.voided = ? ' + extra_conditions, 
                                   self.id, 0])
  end

  def art_drug_orders(extra_conditions='')
    DrugOrder.find(:all,
       :joins => 'INNER JOIN `orders` ON drug_order.order_id = orders.order_id
                  INNER JOIN encounter ON orders.encounter_id = encounter.encounter_id
                  INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
                  INNER JOIN concept_set ON drug.concept_id = concept_set.concept_id AND concept_set = 460',
       :conditions => ['encounter.patient_id = ? AND orders.voided = ? ' + extra_conditions,
                       self.id, 0])
  end

  def latest_art_drugs_given(date = Date.today)
    encounter = DrugOrder.find(:first, 
       :order => 'encounter_datetime DESC', 
       :select => 'encounter.encounter_id,encounter.encounter_datetime',
       :joins => 'INNER JOIN `orders` ON drug_order.order_id = orders.order_id
                  INNER JOIN encounter ON orders.encounter_id = encounter.encounter_id
                  INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
                  INNER JOIN concept_set ON drug.concept_id = concept_set.concept_id AND concept_set = 460',
       :conditions => ['encounter.patient_id = ? AND orders.voided = ? AND DATE(encounter_datetime) <= ?',
                       self.id, 0, date])

    drug_orders = DrugOrder.find(:all,
       :joins => 'INNER JOIN `orders` ON drug_order.order_id = orders.order_id
                  INNER JOIN encounter ON orders.encounter_id = encounter.encounter_id
                  INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
                  INNER JOIN concept_set ON drug.concept_id = concept_set.concept_id AND concept_set = 460',
       :conditions => ['encounter.encounter_id = ? AND orders.voided = ?' ,
                       encounter.encounter_id, 0])

    drugs_given = MastercardVisit.drugs_given(self, drug_orders, encounter.encounter_datetime.to_date)
    given_drugs = []
    drugs_given.each do | regimen , values |
      values.split(':')[1].split(';').each do | drug |
        given_drugs << drug
      end
    end
    given_drugs
  end

## DRUGS
  def drug_orders_by_drug_name(drug_name)
    #TODO needs optimization
    self.encounters.find_by_type_name("Give drugs").collect{|dispensation_encounter|
      next if dispensation_encounter.voided?
      dispensation_encounter.orders.collect{|order|
  order.drug_orders.collect{|drug_order|
    drug_order if drug_order.drug.name == drug_name
  }
      }
    }.flatten.compact
  end
  
## DRUGS
  def drug_orders_for_date(date)
    date = date.to_date if date.class == Time
    self.drug_orders("AND DATE(encounter_datetime) = '#{date}'")
  end
 
## DRUGS
  # This should only return drug orders for the most recent date 
  def previous_art_drug_orders(date = Date.today)
    date = date.to_date
    previous_art_date = Encounter.find(:first,
                                       :joins => "INNER JOIN orders ON orders.encounter_id = encounter.encounter_id",
                                       :order => 'encounter_datetime DESC',
                                       :conditions => ['patient_id = ? AND encounter_type = ? AND encounter_datetime <= ? AND voided = 0',
                                       self.id,EncounterType.find_by_name('Give drugs').id, "#{date} 00:00:00"]
                                       ).encounter_datetime.to_date rescue nil 

    if previous_art_date
      #because of pre art - we check all drugs dispensed to calculate next appointment date
      #not only ARVs

      return self.art_drug_orders("AND DATE(encounter_datetime) = '#{previous_art_date.to_date}'")
    else
      return nil
    end
  end
 
  def given_art_drug_orders(date = Date.today)
    date = date.to_date
    previous_art_date = Encounter.find(:first,
                                       :joins => "INNER JOIN orders ON orders.encounter_id = encounter.encounter_id",
                                       :order => 'encounter_datetime DESC',
                                       :conditions => ['patient_id = ? AND encounter_type = ? AND encounter_datetime <= ? AND voided = 0',
                                       self.id,EncounterType.find_by_name('Give drugs').id, "#{date} 23:59:59"]
                                       ).encounter_datetime.to_date rescue nil 

    if previous_art_date
      #because of pre art - we check all drugs dispensed to calculate next appointment date
      #not only ARVs

      return self.art_drug_orders("AND DATE(encounter_datetime) = '#{previous_art_date.to_date}'")
    else
      return nil
    end
  end
 
  # This should only return all drug orders for the most recent date 
  def previous_drug_orders(date = Date.today)
    date = date.to_date
    previous_visit_date = Encounter.find(:first,
                                       :joins => "INNER JOIN orders ON orders.encounter_id = encounter.encounter_id",
                                       :order => 'encounter_datetime DESC',
                                       :conditions => ['patient_id = ? AND encounter_type = ? AND encounter_datetime <= ? AND voided = 0',
                                       self.id,EncounterType.find_by_name('Give drugs').id, "#{date} 23:59:59"]
                                       ).encounter_datetime.to_date rescue nil 

    if previous_visit_date
      #because of pre art - we check all drugs dispensed to calculate next appointment date
      #not only ARVs

      return self.drug_orders("AND DATE(encounter_datetime) = '#{previous_visit_date.to_date}'")
    else
      return nil
    end
  end
 
  
## DRUGS
  def cohort_last_art_regimen(start_date=nil, end_date=nil)
    start_date = Encounter.find(:first, :order => "encounter_datetime").encounter_datetime.to_date if start_date.nil?
    end_date = Date.today if end_date.nil?
    
## OPTIMIZE, really, this is ONLY used for cohort and we should be able to use the big set of encounter/regimen names
    dispensation_type_id = EncounterType.find_by_name("Give drugs").id
    #self.encounters.each {|encounter|
    self.encounters.find(:all, 
                         :conditions => ['encounter_type = ? AND encounter_datetime >= ? AND encounter_datetime <= ?',
                                         dispensation_type_id, start_date, end_date],
                         :order => 'encounter_datetime DESC,date_created DESC'
                        ).each {|encounter|
      regimen = encounter.regimen
      return regimen if regimen
    }
    return nil
  end

  # returns short code of the most recent art drugs received
  # Coded to add regimen break down to cohort
  def cohort_last_art_drug_code(start_date=nil, end_date=nil)
    latest_drugs_date =  PatientDispensationAndPrescription.find(:first, :order => 'visit_date DESC', :conditions => ['patient_id = ? AND visit_date < ?', self.id, end_date]).visit_date rescue nil
    latest_drugs =  PatientDispensationAndPrescription.find(:all, :order => 'visit_date DESC', :conditions => ['patient_id = ? AND visit_date = ?', self.id, latest_drugs_date]).map(&:drug)

    latest_drugs.map{|drug| drug.concept.name rescue ' '}.uniq.sort.join(' ')
  end
## DRUGS
  # returns the most recent guardian
  def valid_art_guardian(relationship_type ="ART Guardian")
    guardian_type = RelationshipType.find_by_name(relationship_type)
    return nil if guardian_type.blank?
    # each patient should have 1 corresponding person record
    person = self.people[0]
    begin
      rel = Relationship.find(:first, :conditions => ["voided = 0 AND relationship = ? AND person_id = ?", guardian_type.id, person.id], :order => "date_created DESC") unless person.nil?
      rel = rel.relative.patient unless person.nil?
    rescue
      return nil
    end
    return rel
  end
  
  def art_guardian(return_guardian_type = false)
    RelationshipType.find(:all).each{|rel_type|
      rel = self.valid_art_guardian(rel_type.name)
      return rel_type if return_guardian_type and rel
      return rel if rel
    }
    return nil
  end

  def art_guardian_type
    self.art_guardian(true)
  end

  def set_art_guardian_relationship(guardian,type_of_guardian="ART Guardian")
    raise "Guardian and patient can not be the same person" if self == guardian
    guardian_type = RelationshipType.find_by_name(type_of_guardian) rescue nil
    return if guardian_type.blank?
    
    person = Person.find_or_create_by_patient_id(self.id)
    guardian_person = Person.find_or_create_by_patient_id(guardian.id)
    
    guardian_relationship = Relationship.new
    guardian_relationship.person_id = person.id
    guardian_relationship.relative_id = guardian_person.id
    guardian_relationship.relationship = guardian_type.id
    guardian_relationship.save
  end

  def create_guardian(first_name,last_name,sex)
   guardian = Patient.new()
   guardian.save
   guardian.gender = sex
   guardian.set_name(first_name,last_name)
   guardian.save
   self.set_art_guardian_relationship(guardian)
  end
   
  def art_guardian_of
    self.people.collect{|people| 
      people.related_from.collect{|p| 
        p.person.patient.name unless p.attributes["voided"] == true 
        }
    }.flatten.compact rescue []
  end
  
  def name
    "#{self.given_name} #{self.family_name}"
  end
  
  def name_with_id
    name + " " + self.print_national_id 
  end

  def age(today = Date.today)
    #((Time.now - self.birthdate.to_time)/1.year).floor
    # Replaced by Jeff's code which better accounts for leap years

    return nil if self.birthdate.nil?

    patient_age = (today.year - self.birthdate.year) + ((today.month - self.birthdate.month) + ((today.day - self.birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)
   
    birth_date=self.birthdate
    estimate=self.birthdate_estimated
    if birth_date.month == 7 and birth_date.day == 1 and estimate == 1 and Time.now.month < birth_date.month and self.date_created.year == Time.now.year
       return patient_age + 1
    else
       return patient_age
    end     
  end

  def age=(age)
    age = age.to_i
    patient_estimated_birthyear = Date.today.year - age
    patient_estimated_birthmonth = 7
    patient_estimated_birthday = 1
    self.birthdate = Date.new(patient_estimated_birthyear, patient_estimated_birthmonth, patient_estimated_birthday)
    self.birthdate_estimated = true
    self.save
  end
  
  def age_in_months(reference_date = Time.now)
    if reference_date.nil?
      reference_date = self.encounters.find(:first, :order => 'encounter_datetime').encounter_datetime rescue Time.now
    end
    raise "birthdate is nil" if self.birthdate.nil?
    ((reference_date.to_time - self.birthdate.to_time)/1.month).floor
  end

  def child?
    return self.age <= 14 unless self.age.nil?
    return false
  end

  def adult?
    return !self.child?
  end

  def adult_or_child
    self.child? ? "child" : "adult"
  end

  def age_at_initiation
    initiation_date = self.date_started_art
    return self.age(initiation_date) unless initiation_date.nil?
  end

  def child_at_initiation?
    age_at_initiation = self.age_at_initiation
    return age_at_initiation <= 14 unless age_at_initiation.nil?
  end

  # The only time this is called is with no params... it is always first line, can we kill the param?
  def date_started_art(regimen_type = "ARV First line regimen")

    @@date_started_art ||= Hash.new
    @@date_started_art[self.patient_id] ||= Hash.new
    return @@date_started_art[self.patient_id][regimen_type] if @@date_started_art[self.patient_id].has_key?(regimen_type)

    @@date_started_art[self.patient_id][regimen_type] = self.patient_start_date.start_date rescue nil
    return @@date_started_art[self.patient_id][regimen_type]
=begin

    # handle transfer IN
    if self.transfer_in?
      @@date_started_art[self.patient_id][regimen_type] = self.encounters.find_last_by_type_name("HIV First visit").encounter_datetime
      return @@date_started_art[self.patient_id][regimen_type]
    end
    
    arv_dispensing_dates = []
    dispensation_type_id = EncounterType.find_by_name("Give drugs").id
    self.encounters.each{|encounter|
      next unless encounter.encounter_type == dispensation_type_id
      unless Encounter.dispensation_encounter_regimen_names.blank?
        arv_dispensing_dates << encounter.encounter_datetime if Encounter.dispensation_encounter_regimen_names[encounter.encounter_id] == regimen_type        
      else  
        regimen_concept = DrugOrder.drug_orders_to_regimen(encounter.drug_orders)
        arv_dispensing_dates << encounter.encounter_datetime if regimen_concept && regimen_concept.name == regimen_type
      end
    }     
    # If there are no dispensing dates, try to use the Date of ART Initiation if available
    nil      
    @@date_started_art[self.patient_id][regimen_type] = arv_dispensing_dates.sort.first unless arv_dispensing_dates.nil?
    @@date_started_art[self.patient_id][regimen_type] unless arv_dispensing_dates.nil?
=end
  end


  def get_identifier(identifier)
    identifier_list = self.patient_identifiers.collect{|patient_identifier|
                        #raise patient_identifier.voided
                        next if patient_identifier.voided == 1
                        next unless patient_identifier.type.name == identifier
                        patient_identifier.identifier
                      }.compact rescue nil
    
    return nil if identifier_list.blank?
    return identifier_list[0] if identifier_list.length == 1
    identifier_list
  end

  def set_first_name=(first_name)
    patient_name = self.patient_names.last rescue nil
    patient_name = PatientName.new if patient_name.blank? 
    patient_name.given_name = first_name
    patient_name.patient_id = self.id
    patient_name.save
  end

  def first_name
    return given_name
  end

  def given_name
    self.patient_names.last.given_name unless self.patient_names.blank?
  end

  def set_name(first_name,last_name)

    patient_names = self.patient_names.find(:all,:conditions =>["voided=0"])
    patient_names.each{|patient_name|patient_name.void!('given another name')}

    patientname = PatientName.new()
    patientname.given_name = first_name
    patientname.family_name = last_name
    patientname.patient = self
    patientname.save
  end

  def last_name
    return family_name
  end
  
  def family_name
    self.patient_names.last.family_name unless self.patient_names.blank?
  end

  def update_name!(name, reason)
    self.patient_names[0].void!(reason) unless self.patient_names[0].nil?    
    self.patient_names << name
    self.patient_names(true)
  end

  def other_names
    name=self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("Other name").id)
    return nil if name.nil? or name.identifier==""
    return name.identifier
  end 
   
  def filing_number
    filing_number=self.patient_identifiers.find_first_by_identifier_type(PatientIdentifierType.find_by_name("Filing number").id)
    filingnumber = filing_number.identifier unless filing_number.voided  rescue nil
    return filingnumber unless filingnumber.blank?
    return self.archive_filing_number
  end
  
  def archive_filing_number
    filing_number=self.patient_identifiers.find_first_by_identifier_type(PatientIdentifierType.find_by_name("Archived filing number").id) rescue nil
    filingnumber = filing_number.identifier unless filing_number.voided  rescue nil
    return filingnumber unless filingnumber.blank?
  end
  
  def patient_to_be_archived
   archive_identifier_type = PatientIdentifierType.find_by_name("Archived filing number")
   active_identifier_type = PatientIdentifierType.find_by_name("Filing number")
   active_filing_number = self.filing_number rescue nil
   return nil if active_filing_number.blank?
   archive_filing_number = PatientIdentifier.find(:first,:conditions=>["voided=1 and identifier_type=? and identifier=?",active_identifier_type.id,active_filing_number],:order=>"date_created desc").patient rescue nil
   return archive_filing_number unless archive_filing_number.blank?
  end

  def archived_patient_old_active_filing_number
   active_identifier_type = PatientIdentifierType.find_by_name("Filing number")
   return PatientIdentifier.find(:first,:conditions=>["voided=1 and patient_id=? and identifier_type=?",self.id,active_identifier_type.id],:order=>"date_created desc").identifier rescue nil
  end
  
  def archived_patient_old_dormant_filing_number
   dormant_identifier_type = PatientIdentifierType.find_by_name("Archived filing number")
   return PatientIdentifier.find(:first,:conditions=>["voided=1 and patient_id=? and identifier_type=?",self.id,dormant_identifier_type.id],:order=>"date_created desc").identifier rescue nil
  end
  
  def self.printing_filing_number_label(number=nil)
   return number[5..5] + " " + number[6..7] + " " + number[8..-1] unless number.nil?
  end

  def tb_patient?
    return self.programs.collect{|program|program.name}.include?("Tuberculosis (TB)")
  end

  def hiv_patient?
    return self.programs.collect{|program|program.name}.include?("HIV")
  end

  def art_patient?
    # TODO - this does not necessarily mean they are on ART
    return self.hiv_patient?
  end
  
  def ARV_national_id
    begin
      self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("Arv national id").id, :conditions => ['voided = ?', 0]).identifier 
    rescue
     return nil
   end
  end

  def art_number
    begin
      PatientIdentifier.find(:first,:conditions => ["identifier_type =? AND patient_id = ? AND voided = 0",
        PatientIdentifierType.find_by_name("ART number").id,self.id]).identifier 
    rescue
     return nil
   end
  end

  def tb_number
    begin
      PatientIdentifier.find(:first,:conditions => ["identifier_type =? AND patient_id = ? AND voided = 0",
        PatientIdentifierType.find_by_name("TB treatment ID").id,self.id]).identifier 
    rescue
     return nil
   end
  end

  def image_arv_number
    arv_number = self.arv_number
    return if arv_number.blank?
    arv_code = Location.current_arv_code
    number = arv_number.gsub(arv_code,'').to_i.to_s
    if number.length == 1
      number = "000" + number
    elsif number.length == 2
      number = "00" + number
    elsif number.length == 3
      number = "00" + number
    end  
    arv_code + number
  end

  def tb_number=(value)
    tb_number_type = PatientIdentifierType.find_by_name('TB treatment ID')
    prif = value.match(/(.*)[A-Z]/i)[0].upcase rescue "ZA"
    number = value.match(/[0-9](.*)/i)[0] rescue nil
    return if number.blank?

    existing_tb_numbers = PatientIdentifier.find(:all,
                           :conditions => ["identifier_type=? AND voided=0 AND patient_id=?",
                           tb_number_type.id,self.id])
    existing_tb_numbers.each{|ident|
      ident.voided = 1
      ident.voided_by = User.current_user.id
      ident.date_voided = Time.now()
      ident.void_reason = "Given new number"
      ident.save
    }

    unless number.blank?
      tb_number = PatientIdentifier.new()
      tb_number.identifier = "#{prif} #{number}"
      tb_number.identifier_type = tb_number_type.id
      tb_number.patient_id = self.id
      tb_number.save
    end rescue nil
  end

  def PreARV_number
    begin
      self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("Pre ARV number ID").id, 
          :conditions => ['voided = ?', 0]).identifier 
    rescue
     return nil
   end
  end

  def pre_arv_number
    self.PreARV_number
  end

  def pre_arv_number=(value)
   arv_number_type = PatientIdentifierType.find_by_name('Pre ARV number ID')
   number = value.match(/[0-9](.*)/i)[0]

   existing_arv_numbers = PatientIdentifier.find(:all,
                          :conditions => ["identifier_type=? AND voided = 0 AND patient_id=?",
                          arv_number_type.id,self.id])
   existing_arv_numbers.each{|ident|
     ident.voided = 1
     ident.voided_by = User.current_user.id
     ident.date_voided = Time.now()
     ident.void_reason = "Given new number"
     ident.save
   }

   unless number.blank?
     begin
       arv_number = PatientIdentifier.new()
       arv_number.identifier = number
       arv_number.identifier_type = arv_number_type.id
       arv_number.patient_id = self.id
       arv_number.save
     rescue
       ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET voided = 0
WHERE patient_id = #{self.patient_id} and identifier = '#{number}'
EOF
     end
   end rescue nil
  end

  def arv_number
    self.ARV_national_id
  end

  def arv_number=(value)
    arv_number_type = PatientIdentifierType.find_by_name('Arv national id')
    prif = value.match(/(.*)[A-Z]/i)[0].upcase rescue Location.current_arv_code
    number = value.match(/[0-9](.*)/i)[0]

    existing_arv_numbers = PatientIdentifier.find(:all,
                           :conditions => ["identifier_type=? AND voided = 0 AND patient_id=?",
                           arv_number_type.id,self.id])
    existing_arv_numbers.each{|ident|
      ident.voided = 1
      ident.voided_by = User.current_user.id
      ident.date_voided = Time.now()
      ident.void_reason = "Given new number"
      ident.save
    }
 
    unless number.blank?
      begin
        arv_number = PatientIdentifier.new()
        arv_number.identifier = "#{prif} #{number}"
        arv_number.identifier_type = arv_number_type.id
        arv_number.patient_id = self.id
        arv_number.save
      rescue 
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET voided = 0
WHERE patient_id = #{self.patient_id} and identifier = '#{prif} #{number}'
EOF
      end   
    end rescue nil
  end

  def art_number=(value)
    arv_number_type = PatientIdentifierType.find_by_name('ART number')
    prif = 'Pre' #value.match(/(.*)[A-Z]/i)[0].upcase rescue Location.current_arv_code
    number = value.match(/[0-9](.*)/i)[0]

    existing_arv_numbers = PatientIdentifier.find(:all,
                           :conditions => ["identifier_type=? AND voided = 0 AND patient_id=?",
                           arv_number_type.id,self.id])
    existing_arv_numbers.each{|ident|
      ident.voided = 1
      ident.voided_by = User.current_user.id
      ident.date_voided = Time.now()
      ident.void_reason = "Given new number"
      ident.save
    }
 
    unless number.blank?
      begin
        arv_number = PatientIdentifier.new()
        arv_number.identifier = "#{prif} #{number}"
        arv_number.identifier_type = arv_number_type.id
        arv_number.patient_id = self.id
        arv_number.save
      rescue 
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET voided = 0
WHERE patient_id = #{self.patient_id} and identifier = '#{prif} #{number}'
EOF
      end   
    end rescue nil
  end

  def previous_arv_number
    begin
      self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("Previous ARV number").id, :conditions => ['voided = ?', 0]).identifier 
    rescue
     return nil
   end
  end

  def previous_arv_number=(value)
    arv_number_type = PatientIdentifierType.find_by_name('Previous ARV number')
    prif = value.match(/(.*)[A-Z]/i)[0].upcase rescue Location.current_arv_code
    number = value.match(/[0-9](.*)/i)[0]

    existing_arv_numbers = PatientIdentifier.find(:all,
                           :conditions => ["identifier_type=? AND voided = 0 AND patient_id=?",
                           arv_number_type.id,self.id])
    existing_arv_numbers.each{|ident|
      ident.voided = 1
      ident.voided_by = User.current_user.id
      ident.date_voided = Time.now()
      ident.void_reason = "Given new number"
      ident.save
    }

    unless number.blank?
      begin
        arv_number = PatientIdentifier.new()
        arv_number.identifier = "#{prif} #{number}"
        arv_number.identifier_type = arv_number_type.id
        arv_number.patient_id = self.id
        arv_number.save
      rescue
        ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET voided = 0
WHERE patient_id = #{self.patient_id} and identifier = '#{prif} #{number}'
EOF
      end
    end rescue nil
  end

  def self.find_by_arvnumber(number)
   patient = nil
   match = number.match(/([a-zA-Z]+) *(\d+)/)
   raise "It appears you have not entered the ARV code for the Location" unless match
   (arv_header, arv_number) = match[1..2]
   unless arv_header.blank? and arv_number.blank?
     identifier = PatientIdentifier.find(:all, :conditions => ["voided = 0 AND identifier= ?", arv_header + " " + arv_number.to_i.to_s])  
     patient_id = identifier.first.patient_id unless identifier.blank?
     patient = Patient.find(patient_id) unless patient_id.blank?
     if patient.blank?
      identifier = PatientIdentifier.find(:all, :conditions => ["voided = 0 AND identifier= ?", arv_header + arv_number.to_i.to_s])  
      patient_id = identifier.first.patient_id unless identifier.blank?
      patient = Patient.find(patient_id) unless patient_id.blank?
     end
     patient unless patient.nil? or patient.voided
   end
  end

  def national_id
    national_id = PatientIdentifier.find(:first,
                                         :conditions =>["voided = 0 AND patient_id=? AND identifier_type=?",
                                         self.id,PatientIdentifierType.find_by_name("New national id").id])

    unless national_id.blank?
      return national_id.identifier 
    end

    national_id = PatientIdentifier.find(:first,
                                         :conditions =>["voided = 0 AND patient_id=? AND identifier_type=?",
                                         self.id,PatientIdentifierType.find_by_name("National id").id])
    national_id.identifier unless national_id.blank?
  end

  def new_national_id
    national_id = PatientIdentifier.find(:first,
                                         :conditions =>["voided = 0 AND patient_id=? AND identifier_type=?",
                                         self.id,PatientIdentifierType.find_by_name("New national id").id])
    national_id.identifier unless national_id.blank?
  end

  def person_address
    address = self.patient_addresses.collect{|add|add unless add.voided}.compact rescue []
    address.last.city_village unless address.blank?
  end 
  
  def print_national_id
    national_id = self.national_id
    if national_id.length == 13
      return national_id[0..4] + "-" + national_id[5..8] + "-" + national_id[9..-1] 
    else
      return national_id[0..2] + "-" + national_id[3..-1] 
    end rescue nil
  end
  
  def mastercard
    Mastercard.new(self)
  end
  
  def birthdate_for_printing
    birthdate = self.birthdate
    if self.birthdate_estimated
      if birthdate.day == 1 and birthdate.month == 7
        birth_date_string = birthdate.strftime("??/???/%Y")
      elsif birthdate.day==15 
        birth_date_string = birthdate.strftime("??/%b/%Y")
      else  
        birth_date_string = birthdate.strftime("%d/%b/%Y")
      end
    else
      birth_date_string = birthdate.strftime("%d/%b/%Y")
    end
    birth_date_string
  end
  
  def art_initial_staging_conditions
    staging_observations = self.encounters.find_by_type_name("HIV Staging").collect{|e|e.observations unless e.voided?}.flatten.compact rescue nil
    #puts staging_observations.collect{|so|so.to_short_s + "  " + ".........."}
    staging_observations.collect{|obs|obs.concept.to_short_s if obs.value_coded == Concept.find_by_name("Yes").id}.compact rescue nil
  end

  def staging_encounter
    #This method will return staging obs captured soon b4 starting art
    #staging_observations = Array.new()
    art_start_date = self.date_started_art 
    art_start_date = Time.now if art_start_date.nil?

    staging_encounter = nil

    staging_encounters = self.encounters.find(:all, 
           :joins => "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.voided = 0",
           :conditions => ["encounter.encounter_type = ? AND encounter_datetime <= ?", 
           EncounterType.find_by_name("HIV Staging").id, art_start_date.strftime("%Y-%m-%d 23:59:59")],
           :order => "encounter.encounter_datetime DESC")

    (staging_encounters || []).each do | encounter |
      if encounter.reason_for_starting_art
        staging_encounter = encounter
        break
      end
    end
    
    #This will return the earliest staging encounter for patients who have staging encounter datetime after art was started 
    #AND transfer ins whose hiv staging encounter datetime if usually later than date started art
    #TODO probably default the hiv staging encounter to date of starting art when saving HIV first visit info for Transfer ins??!!
    if staging_encounter.nil?
      staging_encounters = self.encounters.find(:all, 
           :joins => "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.voided = 0",
           :conditions => ["encounter.encounter_type = ?", EncounterType.find_by_name("HIV Staging").id],
           :order => "encounter.encounter_datetime ASC") rescue nil
    
      (staging_encounters || []).each do | encounter |
        if encounter.reason_for_starting_art
          staging_encounter = encounter
          break
        end
      end
    end

    return staging_encounter
  end

  def who_stage
    staging_enc = self.staging_encounter
    stage = nil
    if staging_enc
      stage = staging_enc.who_stage
    end

    stage
  end

  def who_reason_started
    PersonAttribute.who_stage(self.id) 
  end
 
  def reason_antiretrovirals_started
    PersonAttribute.art_reason(self.id) 
  end
 
  def reason_for_art_eligibility(options = {})
   
    if options[:cached]
      attribute_type = PersonAttributeType.find_by_name("Reason antiretrovirals started").id
      reason_name = self.person_attributes.find_by_person_attribute_type_id(attribute_type).value rescue nil
      if reason_name
        return Concept.find_by_name(reason_name)
      else
        return nil
      end
    end

    # Calculate reason only after patient has been staged
    eligibility_enc = self.staging_encounter
    return unless eligibility_enc

    return eligibility_enc.reason_for_starting_art
  end

  ## This code has been moved to Encounter#reason_for_starting_art
  # TO BE DELETED!
  def old_reason_for_art_eligibilty
    new_guideline_start_date = GlobalProperty.find_by_property('new.guideline.start.date').property_value.to_date rescue '2011-07-01'.to_date
    who_stage = self.who_stage
    child_at_initiation = self.child_at_initiation?
    adult_or_peds = child_at_initiation ? "peds" : "adult" #returns peds or adult
    if child_at_initiation.nil?
      #if self.child_at_initiation? returns nil
      adult_or_peds = self.child? ? "peds" : "adult"
    end
    yes_concept_id = Concept.find_by_name("Yes").id rescue 3
    #check if the first positive hiv test recorded at registaration was PCR
          #check if patient had low cd4 count

    low_cd4_count_250 = false
    low_cd4_count_350 = false

    latest_cd4_count = self.cd4_count_when_starting rescue nil
    if not latest_cd4_count.values[0][:value_numeric].blank?
      cd4_count = latest_cd4_count.values[0][:value_numeric]
      value_modifier = latest_cd4_count.values[0][:value_modifier]
      if not (value_modifier == ">") and cd4_count <= 250
        low_cd4_count_250 = true
      elsif value_modifier == ">" and cd4_count == 250
        low_cd4_count_250 = false
      elsif not(value_modifier == ">") and cd4_count <= 350
        low_cd4_count_350 = true
      elsif value_modifier == ">" and cd4_count == 350
        low_cd4_count_350 = false
      elsif cd4_count <= 250
        low_cd4_count_250 = true
      elsif cd4_count <= 350
        low_cd4_count_350 = true
      end
    end unless latest_cd4_count.blank?

    latest_cd4_count_not_available = latest_cd4_count.values[0][:value_numeric].blank? rescue true
    if latest_cd4_count_not_available
      cd4_count_available = Concept.find_by_name("CD4 count available")
      cd4_count_done = Observation.find(:first, :conditions =>["patient_id = ?
      AND DATE(obs_datetime)=? AND concept_id = ? AND voided = 0",
      self.id,staging_encounter.encounter_datetime.to_date,
      cd4_count_available.id]).value_coded == yes_concept_id rescue false
      if cd4_count_done
        ["CD4 Count < 250","CD4 Count < 350"].each do |c|
          concept_id = Concept.find_by_name(c).concept_id
          cd4_count = Observation.find(:first, :conditions =>["patient_id = ?
          AND DATE(obs_datetime)=? AND concept_id = ? AND voided = 0",
          self.id,staging_encounter.encounter_datetime.to_date,
          concept_id]).value_coded == yes_concept_id rescue false
          if c == "CD4 Count < 250" and cd4_count
            low_cd4_count_250 = true
          elsif c == "CD4 Count < 350" and cd4_count
            low_cd4_count_350 = true
          end
        end
      end
    end

    pregnant_woman = false
    breastfeeding_woman = false
    first_hiv_enc_date = encounters.find(:first,
                        :conditions =>["encounter_type=?",EncounterType.find_by_name("HIV Staging").id],
                        :order =>"encounter_datetime desc").encounter_datetime.to_date rescue "2010-01-01".to_date

    if self.sex == "Female"
      if first_hiv_enc_date >= "2011-07-01".to_date
        if self.observations.find(:first,:conditions => ["concept_id = ? AND value_coded=? AND voided = 0",Concept.find_by_name("Pregnant").id,yes_concept_id]) != nil
          pregnant_woman = true
        end
        if self.observations.find(:first,:conditions => ["concept_id = ? AND value_coded=? AND voided = 0",Concept.find_by_name("Breastfeeding").id,yes_concept_id]) != nil
          breastfeeding_woman = true
        end
      end
    end

    if self.child_at_initiation? || self.child?
      date_of_positive_hiv_test = self.date_of_positive_hiv_test
      latest_staging_date = self.encounters.find_last_by_type_name("HIV staging").encounter_datetime rescue Time.now()
      age_in_months = self.age_in_months(latest_staging_date)
      cd4_count_less_than_750 = false

      if age_in_months >= 24 and age_in_months < 56
        if not latest_cd4_count.blank?
          cd4_count = latest_cd4_count.values[0][:value_numeric]
          value_modifier = latest_cd4_count.values[0][:value_modifier]
          if not (value_modifier == ">") and cd4_count <= 750
            cd4_count_less_than_750 = true
          elsif value_modifier == ">" and cd4_count == 750
            cd4_count_less_than_750 = false
          elsif cd4_count <= 750
            cd4_count_less_than_750 = true
          end
        end

        latest_cd4_count_not_available = latest_cd4_count.values[0][:value_numeric].blank? rescue true
        if latest_cd4_count_not_available
          cd4_count_available = Concept.find_by_name("CD4 count available")
          cd4_count_done = Observation.find(:first, :conditions =>["patient_id = ?
          AND DATE(obs_datetime)=? AND concept_id = ? AND voided = 0",
          self.id,staging_encounter.encounter_datetime.to_date,
          cd4_count_available.id]).value_coded == yes_concept_id rescue false
          if cd4_count_done
            ["CD4 Count < 750"].each do |c|
              concept_id = Concept.find_by_name(c).concept_id
              cd4_count = Observation.find(:first, :conditions =>["patient_id = ?
              AND DATE(obs_datetime)=? AND concept_id = ? AND voided = 0",
              self.id,staging_encounter.encounter_datetime.to_date,
              concept_id]).value_coded == yes_concept_id rescue false
              if c == "CD4 Count < 750" and cd4_count
                cd4_count_less_than_750 = true
              end
            end
          end
        end
      end

      presumed_hiv_status_conditions = false
      low_cd4_percent = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                                 Concept.find_by_name("CD4 percentage < 25").id,
                                                 (Concept.find_by_name("Yes").id rescue 3)]) != nil
      thresholds = {
          0=>4000, 1=>4000, 2=>4000,
          3=>3000, 4=>3000,
          5=>2500,
          6=>2000, 7=>2000, 8=>2000, 9=>2000, 10=>2000, 11=>2000, 12=>2000, 13=>2000, 14=>2000, 15=>2000
        }
      low_lymphocyte_count = self.observations.find(:first, :conditions => ["value_numeric <= ? AND concept_id = ? AND voided = 0",thresholds[self.age],
                                              Concept.find_by_name("Lymphocyte count").id]) != nil
      first_hiv_test_was_pcr = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                                    Concept.find_by_name("First positive HIV Test").id,
                                                    (Concept.find_by_name("PCR Test").id rescue 463)]) != nil
      first_hiv_test_was_rapid = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                                    Concept.find_by_name("First positive HIV Test").id,
                                                    (Concept.find_by_name("Rapid Test").id rescue 464)]) != nil
      pneumocystis_pneumonia = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                                    Concept.find_by_name("Pneumocystis pneumonia").id,
                                                    (Concept.find_by_name("Yes").id rescue 3)]) != nil
      candidiasis_of_oesophagus = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                                    Concept.find_by_name("Candidiasis of oesophagus").id,
                                                    (Concept.find_by_name("Yes").id rescue 3)]) != nil
      #check for Cryptococal meningitis or other extrapulmonary meningitis
      cryptococcal_meningitis = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                                    Concept.find_by_name("Cryptococcal meningitis").id,
                                                    (Concept.find_by_name("Yes").id rescue 3)]) != nil
      severe_unexplained_wasting = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                            Concept.find_by_name("Severe unexplained wasting / malnutrition not responding to treatment(weight-for-height/ -age less than 70% or MUAC less than 11cm or oedema)").id,
                                            (Concept.find_by_name("Yes").id rescue 3)]) != nil
      toxoplasmosis_of_the_brain = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                            Concept.find_by_name("Toxoplasmosis of the brain (from age 1 month)").id,
                                            (Concept.find_by_name("Yes").id rescue 3)]) != nil
      oral_thrush = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                            Concept.find_by_name("Oral thrush").id,
                                            (Concept.find_by_name("Yes").id rescue 3)]) != nil
      sepsis_severe = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                            Concept.find_by_name("Sepsis, severe").id,
                                            (Concept.find_by_name("Yes").id rescue 3)]) != nil
      pneumonia_severe = self.observations.find(:first,:conditions => ["(concept_id = ? and value_coded = ? AND voided = 0)",
                                            Concept.find_by_name("Pneumonia, severe").id,
                                            (Concept.find_by_name("Yes").id rescue 3)]) != nil
      hiv_staging = self.encounters.find_by_type_name("HIV Staging").first
      if pneumocystis_pneumonia or candidiasis_of_oesophagus or cryptococcal_meningitis or severe_unexplained_wasting or toxoplasmosis_of_the_brain or (oral_thrush and sepsis_severe) or (oral_thrush and pneumonia_severe) or (sepsis_severe and pneumonia_severe)
        presumed_hiv_status_conditions = true
      end
      if age_in_months <= 17 and first_hiv_test_was_rapid and presumed_hiv_status_conditions
        return Concept.find_by_name("Presumed HIV Disease")
      elsif who_stage >= 3
        return Concept.find_by_name("WHO stage #{who_stage} #{adult_or_peds}")
      elsif age_in_months <= 12 and first_hiv_test_was_pcr and hiv_staging != nil #Prevents assigning reason for art b4 staging encounter
        return Concept.find_by_name("PCR Test")
      elsif age_in_months >= 12 and age_in_months < 24 and first_hiv_enc_date >= new_guideline_start_date
        return Concept.find_by_name("Child HIV positive")
      elsif (age_in_months >= 24 and age_in_months < 56) and cd4_count_less_than_750 and first_hiv_enc_date >= new_guideline_start_date
        return Concept.find_by_name("CD4 count < 750")
      elsif low_cd4_count_350 and first_hiv_enc_date >= new_guideline_start_date
        return Concept.find_by_name("CD4 count < 350")
      elsif low_cd4_count_250
        return Concept.find_by_name("CD4 count < 250")
      elsif low_lymphocyte_count and who_stage == 2
        return Concept.find_by_name("Lymphocyte count below threshold with WHO stage 2")
      elsif pregnant_woman
        return Concept.find_by_name("Pregnant")
      elsif breastfeeding_woman
        return Concept.find_by_name("Breastfeeding")
      end
    else #adult patients
      if(who_stage >= 3)
        return Concept.find_by_name("WHO stage #{who_stage} #{adult_or_peds}")
      else
        if low_cd4_count_350 and first_hiv_enc_date >= new_guideline_start_date
          return Concept.find_by_name("CD4 count < 350")
        elsif low_cd4_count_250
          return Concept.find_by_name("CD4 count < 250")
        elsif low_lymphocyte_count and who_stage == 2
          return Concept.find_by_name("Lymphocyte count below threshold with WHO stage 2")
        elsif pregnant_woman
          return Concept.find_by_name("Pregnant")
        elsif breastfeeding_woman
          return Concept.find_by_name("Breastfeeding")
        end
      end
      return nil
    end
  end
  
## DRUGS
  def date_last_art_prescription_is_finished(from_date = Date.today)
    #Find last drug order
    last_10_give_drugs_encounters = self.encounters.find(:all, :conditions => ["encounter_type = ? AND encounter_datetime < ?", EncounterType.find_by_name("Give drugs").id, from_date], :limit => 10, :order => "encounter_datetime DESC, date_created DESC")
    last_art_encounter = nil
    last_10_give_drugs_encounters.each{|drug_encounter|
      if drug_encounter.arv_given?
  last_art_encounter = drug_encounter
  break
      end
    }
    return nil if last_art_encounter.nil?
    # Find when they needed to come back to be adherent
    dates_of_return_if_adherent = Array.new
    last_art_encounter.orders.each{|order|
      order.drug_orders.each{|drug_order|
        dates_of_return_if_adherent << drug_order.date_of_return_if_adherent(from_date)
      }
    }
    # If there are multiple values return the first
    return dates_of_return_if_adherent.sort.first
  end

  # Use this when searching for ART patients
  # use exclude_outcomes to remove dead patients, transfer outs, etc
  def self.art_patients(options = nil)
    #TODO make this efficient
    #
    # Get all patients in the HIV program
    patients = Program.find_by_name("HIV").patients
    raise "Can not both exclude and include outcomes" if options[:include_outcomes] and options[:exclude_outcomes] unless options.nil?

    # Remove any patients who have not had an ART visit
    patients.delete_if{|patient|
      patient.encounters.find_first_by_type_name("ART visit").nil?
    }

    return patients if options.nil?

    if options[:include_outcomes]
      patients.delete_if{|patient|
        not options[:include_outcomes].include?(patient.outcome)
      }
    elsif options[:exclude_outcomes]
      patients.delete_if{|patient|
        options[:exclude_outcomes].include?(patient.outcome)
      }
    end

    return patients

  end

=begin 
  # Disabled because patient_outcomes view already handles this   
  # CRON!
  def self.update_defaulters(date = Date.today)

    outcome_concept = Concept.find_by_name("Outcome")
    defaulter_concept = Concept.find_by_name("Defaulter")
    defaulters_added_count = 0
    Patient.art_patients(:include_outcomes => [Concept.find_by_name("On ART")]).each{|patient|
      if patient.defaulter?(date)

  #puts "Adding defaulter observation on #{date.to_s} to #{patient.name}"

  observation = Observation.new
  observation.patient = patient
  observation.concept_id = outcome_concept.id
  observation.value_coded = defaulter_concept.id
  observation.encounter = nil
  observation.obs_datetime = date
  observation.creator = User.current_user.id rescue User.find(:first).id 
  observation.save or raise "#{observation.errors}"
  defaulters_added_count += 1
      end
    }
    return defaulters_added_count
  end
=end

  # MOH defines a defaulter as someone who has not showed up 2 months after their drugs have run out
  def defaulter?(from_date = Date.today, number_missed_days_required_to_be_defaulter = 60)
    outcome = self.outcome(from_date).name rescue ''
    if outcome.match(/Dead|Transfer/)
      return false
    elsif outcome == "Defaulter"
      return true
    end
    date_last_art_prescription_is_finished = self.date_of_return_if_adherent(from_date) #self.date_last_art_prescription_is_finished
    date_last_art_prescription_is_finished = from_date if date_last_art_prescription_is_finished.nil?
    return true if date_last_art_prescription_is_finished.to_date + number_missed_days_required_to_be_defaulter < from_date.to_date
    return false
  end

  def set_transfer_in(status, date)
    return if status.nil?
    hiv_first_visit = self.encounters.find_first_by_type_name("HIV First visit")
    if hiv_first_visit.blank?
      hiv_first_visit = Encounter.new
      hiv_first_visit.patient = self
      hiv_first_visit.type = EncounterType.find_by_name("HIV First visit")
      hiv_first_visit.encounter_datetime = date
      hiv_first_visit.provider_id = User.current_user.id
      hiv_first_visit.save
    end

    yes_no="No" if status == false
    yes_no="Yes" if status == true
    ever_received_art = Observation.new
    ever_received_art.encounter = hiv_first_visit
    ever_received_art.patient = self
    ever_received_art.concept = Concept.find_by_name("Ever received ART")
    ever_received_art.value_coded = Concept.find_by_name(yes_no).id
    ever_received_art.obs_datetime = date
    ever_received_art.save

    ever_registered_at_art_clinic = Observation.new
    ever_registered_at_art_clinic.encounter = hiv_first_visit
    ever_registered_at_art_clinic.patient = self
    ever_registered_at_art_clinic.concept = Concept.find_by_name("Ever registered at ART clinic")
    ever_registered_at_art_clinic.value_coded = Concept.find_by_name(yes_no).id
    ever_registered_at_art_clinic.obs_datetime = date
    ever_registered_at_art_clinic.save
  end

  def transfer_in?
    return false unless self.hiv_patient?
    hiv_first_visit = self.encounters.find_last_by_type_name("HIV First visit")
    return false if hiv_first_visit.blank?
    return false if hiv_first_visit.observations.find_last_by_concept_name("Ever registered at ART clinic").blank?
    yes_concept = Concept.find_by_name("Yes")
    return true if hiv_first_visit.observations.find_last_by_concept_name("Ever registered at ART clinic").answer_concept == yes_concept
    return false
  end

  def transfer_in_with_letter?
    return false unless transfer_in?
    hiv_first_visit = self.encounters.find_last_by_type_name("HIV First visit")
    return false if hiv_first_visit.observations.find_last_by_concept_name("Has transfer letter").nil? 
    yes_concept = Concept.find_by_name("Yes")
    has_letter = (hiv_first_visit.observations.find_last_by_concept_name("Has transfer letter").answer_concept == yes_concept)
    return has_letter
  end


  def previous_art_visit_encounters(date = Date.today)
    return self.encounters.find(:all, :conditions => ["encounter_type = ? AND DATE(encounter_datetime) <= DATE(?)",EncounterType.find_by_name("ART Visit").id, date],  :order => "encounter_datetime DESC")
  end

  def art_visit_encounters(date = Date.today,type = 'ART Visit')
    return self.encounters.find(:all, :conditions => ["encounter_type = ? AND DATE(encounter_datetime) = DATE(?)",EncounterType.find_by_name(type).id, date],  :order => "encounter_datetime DESC")
  end

## DRUGS
  def prescriptions(date = Date.today,type = 'ART Visit')
    prescriptions = Array.new
    art_visit_encounters(date,type).each{|followup_encounter|
      prescriptions << followup_encounter.to_prescriptions
    }
    return prescriptions.flatten.compact
  end

## DRUGS
  def art_quantities_including_amount_remaining_after_previous_visit(from_date)
    if self.arvs_dispensed?(from_date) 
      drug_orders = self.given_art_drug_orders(from_date)
    else
      drug_orders = self.previous_drug_orders(" AND DATE(encounter.encounter_datetime)='#{from_date.to_date}'")
    end
    return nil if drug_orders.nil? or drug_orders.empty?
    quantity_by_drug = Hash.new(0)
    quantity_counted_by_drug = Hash.new(0)
    drug_orders.each{|drug_order|
#      puts drug_order.drug.name
#      puts drug_order.quantity
#      puts
      quantity_by_drug[drug_order.drug] += drug_order.quantity
      quantity_counted_by_drug[drug_order.drug] = drug_order.quantity_remaining_from_last_order
    }
    total_quantity_available_by_drug = Hash.new(0)
    quantity_by_drug.each{|drug, quantity|
      total_quantity_available_by_drug[drug] = quantity + quantity_counted_by_drug[drug]
    }
    return total_quantity_available_by_drug
  end

## DRUGS
  def art_amount_remaining_if_adherent(from_date,use_visit_date=true,previous_art_date=nil)
    if use_visit_date
      drug_orders = self.previous_art_drug_orders(from_date)
    else
      drug_orders = self.previous_art_drug_orders(previous_art_date)
    end  
    days_since_order = (from_date - drug_orders.first.date).to_i rescue nil
    return if days_since_order.blank?
    amount_remaining_if_adherent_by_drug = Hash.new(0)

    consumption_by_drug = Hash.new
    drug_orders.each{|drug_order|
      consumption_by_drug[drug_order.drug_inventory_id] = drug_order.daily_consumption
    }
    
    date = use_visit_date ? from_date : previous_art_date
    art_quantities_including_amount_remaining_after_previous_visit(date).each{|drug, quantity|
      next if consumption_by_drug[drug.id].blank?
      amount_remaining_if_adherent_by_drug[drug] = quantity - (days_since_order * consumption_by_drug[drug.id])
    }

    return amount_remaining_if_adherent_by_drug
  end

  def num_days_overdue(from_date)
    self.art_amount_remaining_if_adherent(from_date)
  end

  # Return the earliest date that the patient needs to return to be adherent
## DRUGS
  def return_dates_by_drug(from_date)
    if self.arvs_dispensed?(from_date) 
      drug_orders = self.given_art_drug_orders(from_date)
    else
      drug_orders = self.previous_drug_orders(" AND DATE(encounter.encounter_datetime)='#{from_date.to_date}'")
    end
    return nil if drug_orders.nil? or drug_orders.empty?
    dates_drugs_were_dispensed = drug_orders.first.date
    date_of_return_by_drug = Hash.new(0)

    consumption_by_drug = Hash.new
    drug_orders.each{|drug_order|
      consumption_by_drug[drug_order.drug] = drug_order.daily_consumption
    }

    art_quantities_including_amount_remaining_after_previous_visit(from_date).each{|drug, quantity|
      days_worth_of_drugs = quantity/consumption_by_drug[drug]
      date_of_return_by_drug[drug] = dates_drugs_were_dispensed + days_worth_of_drugs 
    }
    return date_of_return_by_drug
  end

  def date_of_return_if_adherent(from_date)
    return_dates = return_dates_by_drug(from_date)
    return_dates.values.sort.first unless return_dates.nil?
  end

## DRUGS
  def num_days_overdue_by_drug(from_date)
    num_days_overdue_by_drug = Hash.new
    return_dates_by_drug = return_dates_by_drug(from_date)
    return_dates_by_drug.each{|drug,date|
      num_days_overdue_by_drug[drug] = (from_date - date).floor
    } unless return_dates_by_drug.nil?
    return num_days_overdue_by_drug
  end


  def recommended_appointment_date(from_date = Date.today,cal_next_appointment_date=true)
    
#
#   Use the date of perfect adherence to determine when a patient should return (this includes pill count calculations)
# Give the patient a 2 day buffer
    if cal_next_appointment_date
      adherent_return_date = date_of_return_if_adherent(from_date)
      return nil if adherent_return_date.nil?
      recommended_appointment_date = adherent_return_date - 2
    else
      recommended_appointment_date = from_date.to_date
    end  

    easter = Patient.date_for_easter(recommended_appointment_date.year)
    good_friday = easter - 2
    easter_monday = easter + 1
    # new years, martyrs, may, freedom, republic, christmas, boxing
#    holidays = [[1,1],[3,3],[5,1],[6,14],[7,6],[12,25],[12,26], [good_friday.month,good_friday.day]]
    day_month_when_clinic_closed = GlobalProperty.find_by_property("day_month_when_clinic_closed").property_value + "," + good_friday.day.to_s + "-" + good_friday.month.to_s rescue "1-1,3-3,1-5,14-5,6-7,25-12,26-12"
    day_month_when_clinic_closed += "," + good_friday.day.to_s + "-" + good_friday.month.to_s    
    day_month_when_clinic_closed += "," + easter_monday.day.to_s + "-" + easter_monday.month.to_s    
    recommended_appointment_date += 1 # Ugly hack to initialize properly, we subtract a day in the while loop just below
    while(true)
      recommended_appointment_date = recommended_appointment_date - 1

      if self.child?
        followup_days = GlobalProperty.find_by_property("followup_days_for_children").property_value rescue nil
      end

      if followup_days.nil?
        followup_days = GlobalProperty.find_by_property("followup_days").property_value rescue "Monday, Tuesday, Wednesday, Thursday, Friday"
      end
      next unless followup_days.split(/, */).include?(Date::DAYNAMES[recommended_appointment_date.wday])

      ["Saturday","Sunday"].each{|day_to_skip|
        next if Date::DAYNAMES[recommended_appointment_date.wday] == day_to_skip
      }

      # String looks like "1-1,25-12"
      holiday = false
      day_month_when_clinic_closed.split(/, */).each{|date|
        (day,month)=date.split("-") 
        holiday = true if recommended_appointment_date.month.to_s == month and recommended_appointment_date.day.to_s == day
        break if holiday
      }
      next if holiday

      other_clinic_closed_logic = GlobalProperty.find_by_property("other_clinic_closed_logic").property_value rescue "false"
  
      begin
        next if eval other_clinic_closed_logic
      rescue
      end

      break # If we get here then the date is valid
    end

    recommended_appointment_date
  end

  def next_appointment_date(from_date = Date.today , encounter_id = nil , save_next_app_date = false)
    from_date = from_date.to_date

    concept_id = Concept.find_by_name("Appointment date").id
    app_date = Observation.find(:first,:order => "obs_datetime DESC,date_created DESC",
                                :conditions =>["obs_datetime >=? AND obs_datetime <= ? 
                                AND voided=0 AND concept_id=? AND patient_id=? 
                                AND voided = 0",from_date.strftime("%Y-%m-%d 00:00:00"),
                                from_date.strftime("%Y-%m-%d 23:59:59"),concept_id,self.id])
         
    if save_next_app_date and not app_date.blank?
      app_date.voided = 1
      app_date.voided_by = User.current_user.id
      app_date.void_reason = "Given another app date"
      app_date.save
      app_date = nil
    end

    return app_date.value_datetime.to_date unless app_date.blank?

    recommended_appointment_date = self.recommended_appointment_date(from_date)

    return nil if recommended_appointment_date.blank?

    if save_next_app_date and not encounter_id.blank?
      recommended_appointment_date = Patient.available_day_for_appointment(self,recommended_appointment_date.to_date)
      self.record_next_appointment_date(recommended_appointment_date,encounter_id)
    end
    recommended_appointment_date 
  end 
  
  def valid_art_day(from_date)
    self.recommended_appointment_date(from_date.to_date,false)
  end

  def first_drug_dispensation?
    orders = Encounter.find(:all,:joins => "INNER JOIN orders ON encounter.encounter_id=orders.encounter_id",
               :conditions => ["orders.voided=0 AND encounter.patient_id=?",self.id])
    return false if orders.blank?
    return true if orders.length == 1
    return false if orders.length > 1
  end

  def self.available_day_for_appointment(patient,appointment_date)
    use_next_appointment_limit = GlobalProperty.find_by_property("use_next_appointment_limit").property_value rescue "false"
    original_date = appointment_date
    return appointment_date if use_next_appointment_limit == "false" 
    return appointment_date if patient.first_drug_dispensation?

    next_appointment_limit = GlobalProperty.find_by_property("next_appointment_limit").property_value.to_i rescue 170

    appointment_limit = next_appointment_limit
    if Location.current_location.name == 'Zomba Central Hospital' and appointment_date.strftime('%A') == 'Friday'
      appointment_limit = 150
    end


    available_appointment_dates = Hash.new(0)
    Observation.find(:all,
      :conditions =>["concept_id= ? AND voided=0 AND location_id = ? AND value_datetime >= ? AND value_datetime <= ?",
      Concept.find_by_name("Appointment date").id,Location.current_location.id,
      (appointment_date.to_date - 5.day).to_date.strftime("%Y-%m-%d 00:00:00"),
      appointment_date.to_date.strftime("%Y-%m-%d 23:59:59")]).each do | obs |
        available_appointment_dates[obs.value_datetime.to_date]+=1
      end

    set_limit = available_appointment_dates[appointment_date.to_date] 

    return appointment_date if appointment_limit > set_limit

    day_month_when_clinic_closed = GlobalProperty.find_by_property("day_month_when_clinic_closed").property_value + "," + good_friday.day.to_s + "-" + good_friday.month.to_s rescue "1-1,3-3,1-5,14-5,6-7,25-12,26-12"
    followup_days = GlobalProperty.find_by_property("followup_days_for_children").property_value rescue nil
    if followup_days.blank?
      followup_days = GlobalProperty.find_by_property("followup_days").property_value rescue "Monday, Tuesday, Wednesday, Thursday, Friday"
    end

    set_appointment_date = nil
    available_appointment_dates.each do | date , limit |
      day = date.strftime('%d-%m').gsub('0','') ; wk_day = date.strftime('%A') 
      if (next_appointment_limit > limit) and followup_days.include?(wk_day) and not day_month_when_clinic_closed.include?(day) 
        set_appointment_date = date and break if not Location.current_location.name =='Zomba Central Hospital' and not wk_day == 'Friday'
      end 
      appointment_date-= 1.day 
    end 

    return set_appointment_date unless set_appointment_date.blank?
    appointment_date = original_date

    (1.upto(5)).each do | number |
      day = appointment_date.strftime('%d-%m').gsub('0','') ; wk_day = appointment_date.strftime('%A') 
      limit = available_appointment_dates[appointment_date.to_date] 
      if (next_appointment_limit > limit) and followup_days.include?(wk_day) and not day_month_when_clinic_closed.include?(day) 
        set_appointment_date = date and break if not Location.current_location.name =='Zomba Central Hospital' and not wk_day == 'Friday'
      end 
      appointment_date-= 1.day 
    end 

    special_day =  GlobalProperty.find_by_property("special.day.not.to.exide.limit").property_value rescue nil
    special_day = 'Friday' if Location.current_location.name == 'Zomba Central Hospital' 
    original_date = set_appointment_date unless set_appointment_date.blank?  
    
    unless set_appointment_date.blank?
      return original_date if special_day.blank?
      unless special_day.blank?
        return original_date if not original_date.strftime('%A') == special_day
      end
    end

    available_appointment_dates[original_date] = available_appointment_dates[original_date]
    available_appointment_dates[original_date - 1.day] = available_appointment_dates[original_date - 1.day]
    available_appointment_dates[original_date - 2.day] = available_appointment_dates[original_date - 2.day]
    available_appointment_dates[original_date - 3.day] = available_appointment_dates[original_date - 3.day]
    available_appointment_dates[original_date - 4.day] = available_appointment_dates[original_date - 4.day]

    original_date = self.get_date(available_appointment_dates , original_date , followup_days.split(',') , special_day)

    original_date
  end

  def self.get_date(available_appointment_dates , set_date , followup_days , special_day = nil)
    lowest_book_number = nil #next_appointment_limit
     
    ( available_appointment_dates || {} ).each do | date , limit|
      next unless followup_days.include?(date.strftime('%A'))
      next if not special_day.blank? and date.strftime('%A') == special_day 
      lowest_book_number = limit if lowest_book_number.blank?
      if limit <= lowest_book_number
       set_date = date
      end
      lowest_book_number = limit if lowest_book_number > limit
    end
    set_date
  end

  def record_next_appointment_date(date , encounter_id)
    #make sure the obs we are about to create is not already there!!
    obs = Observation.find(:all,
                           :conditions =>["voided=0 AND encounter_id = ? AND concept_id=? AND patient_id=? AND Date(value_datetime)=?",
                           encounter_id,Concept.find_by_name("Appointment date").id,self.patient_id,date.to_date])

    if obs.blank?
      encounter = Encounter.find(encounter_id)
      appointment_date_obs = Observation.new
      appointment_date_obs.encounter_id = encounter.encounter_id
      appointment_date_obs.obs_datetime = encounter.encounter_datetime
      appointment_date_obs.patient = self
      appointment_date_obs.concept_id = Concept.find_by_name("Appointment date").id
      appointment_date_obs.value_datetime = date.to_time
      appointment_date_obs.save
    end

  end

  def last_appointment_date(date=Date.today)
    encounter_type_id = EncounterType.find_by_name("HIV Reception").id
    enc = Encounter.find(:first,:conditions =>["patient_id=? and encounter_type=#{encounter_type_id} and Date(encounter_datetime) <=?",self.id,date.to_date],:order => "encounter_datetime desc")
    enc.encounter_datetime rescue nil
  end

  def Patient.validate_appointment_encounter(encounter)
    appointment_dates_available = Observation.find(:all,:conditions =>["voided=0 and concept_id=? and patient_id=? and Date(obs_datetime)=?",Concept.find_by_name("Appointment date").id,encounter.patient_id,encounter.encounter_datetime.to_date])
    appointment_dates_available.each{|obs|
      if obs.encounter_id != encounter.id
        obs.voided = 1
        obs.voided_by = User.current_user.id
        obs.void_reason = "Given another app date"
        obs.save
      end
    }
  end

  def Patient.date_for_easter(year=Date.today.year)
    goldenNumber = year % 19 + 1

    solarCorrection = (year - 1600) / 100 - (year - 1600) / 400
    lunarCorrection = (((year - 1400) / 100) * 8) / 25

    paschalFullMoon = (3 - (11 * goldenNumber) + solarCorrection - lunarCorrection) % 30 
    --paschalFullMoon if (paschalFullMoon == 29) || (paschalFullMoon == 28 && goldenNumber > 11)

    dominicalNumber = (year + (year / 4) - (year / 100) + (year / 400)) % 7
    daysToSunday = (4 - paschalFullMoon - dominicalNumber) % 7 + 1
    easterOffset = paschalFullMoon + daysToSunday

    return (Time.local(year, "mar", 21) + (easterOffset * 1.day)).to_date
  end

  def Patient.find_by_first_last_sex(first_name, last_name, sex)
    PatientName.find_all_by_family_name(last_name, :conditions => ["LEFT(given_name,1) = ? AND patient.gender = ? AND patient.voided = 0 AND patient_name.voided = 0",first_name.first, sex], :joins => "JOIN patient ON patient.patient_id = patient_name.patient_id").collect{|pn|pn.patient}
  end

  def Patient.find_by_name(name)
    # setup a hash to collect all of the patients in. Use a hash indexed by patient id to remove duplicates
    patient_hash = Hash.new
# find all patient name objects that have a given_name or family_name like the value passed in
    # collect thos patient name objects into an array of patient objects
    PatientName.find(:all,:conditions => ["given_name LIKE ? OR family_name LIKE ?","%#{name}%", "%#{name}%"]).collect{|patient_name| patient_name.patient }.each{ |patient|
    # add the patient objects to the hash
      patient_hash[patient.patient_id] = patient
    }

    # search for patients with other names matching the value passed int
    name_type_id = PatientIdentifierType.find_by_name("Other name").patient_identifier_type_id 
    PatientIdentifier.find(:all, :conditions => ["identifier_type = ? AND identifier LIKE ?",name_type_id,"%#{name}%"]).collect{|patient_identifier| patient_identifier.patient }.each{ |patient|
    # add the patient objects to the hash
      patient_hash[patient.patient_id] = patient
    }
# return just the values that were stored in the hash (since we used the hash to remove duplicates)
    return patient_hash.values
  end
 
  def Patient.find_by_birthyear(start_date)
    year = start_date.to_date.year
    Patient.find(:all,:conditions => ["Year(birthdate) = ?" ,year])
  end 

  def Patient.find_by_birthmonth(start_date)
    month = start_date.to_date.month
    Patient.find(:all,:conditions => ["Month(birthdate)=?" ,month])
  end

  def Patient.find_by_birthday(start_date)
    day = start_date.to_date.day
    Patient.find(:all,:conditions => ["Day(birthdate) =?" ,day])
  end
    
  
  def Patient.find_by_residence(residence)
    PatientAddress.find(:all,:conditions => ["city_village Like ?","%#{residence}%"]).collect{|patient_address| patient_address.patient}
  end 

  def  Patient.find_by_birth_place(birthplace)
   Patient.find(:all,:conditions => ["birthplace Like ?","#{birthplace}%"])
  end
  
  def  Patient.find_by_age(estimate,birth_year)
    [2,5,10].each{|number|
      next unless number == estimate
      estimate == "+/- #{number} years"
      postiveyears = birth_year.to_i +  number
      negativeyears = birth_year.to_i -  number
      return Patient.find(:all,:conditions => ["year(birthdate) >= ? and year(birthdate) <= ?","#{negativeyears}","#{postiveyears}"])
    }
  end

  def Patient.find_by_national_id(number)
    national_id_types = PatientIdentifierType.find(:all, :conditions => ["name in (?)",["National id","New national id"]]).collect{|id_type| id_type.patient_identifier_type_id}
    PatientIdentifier.find(:all,:conditions => ["voided = 0 AND identifier_type in (?) AND identifier = ?",national_id_types,number]).collect{|patient_identifier| patient_identifier.patient}
  end
 
  def Patient.find_by_arv_number(number)
    arv_code = Location.current_arv_code
    arv_national_id_type = PatientIdentifierType.find_by_name("ARV national id").patient_identifier_type_id
    PatientIdentifier.find(:first,:conditions => ["voided = 0 AND identifier_type =?  AND REPLACE(identifier,'#{arv_code}','')=?",arv_national_id_type,number.to_s.gsub(arv_code,"").to_i]).patient rescue nil
  end
 
  attr_accessor :reason
  
  def occupation
    identifier_type_id = PatientIdentifierType.find_by_name("Occupation").patient_identifier_type_id
    value = PatientIdentifier.find_by_patient_id_and_identifier_type(self.id, identifier_type_id, :conditions => "voided = 0")
    value.identifier if value
  end 
 
   def traditional_authority
    identifier_type = PatientIdentifierType.find_by_name("Traditional authority").id
    value = PatientIdentifier.find_by_patient_id_and_identifier_type(self.id,identifier_type,:conditions => "voided = 0")
    value.identifier if value
  end

  def traditional_authority=(value)
    identifier_type_id = PatientIdentifierType.find_by_name("Traditional authority").patient_identifier_type_id
    current_ta = PatientIdentifier.find_by_patient_id_and_identifier_type(self.id, identifier_type_id, :conditions => "voided = 0")
    return if current_ta and current_ta.identifier == value
    # TODO BUG: reason is not set
    current_ta.void! reason unless current_ta.blank?
    saved = PatientIdentifier.create!(:identifier => value, :identifier_type => identifier_type_id, :patient_id => self.id) rescue false

    unless saved
      identifier = PatientIdentifier.find(:first,
                                          :conditions =>["identifier_type=? AND patient_id=? AND identifier=?",
                                          identifier_type_id,self.id,value])
      if identifier
        identifier.voided = 0
        identifier.save
      end
    end
  end


  def occupation=(value)
    identifier_type_id = PatientIdentifierType.find_by_name("Occupation").patient_identifier_type_id
    current_occupation = PatientIdentifier.find_by_patient_id_and_identifier_type(self.id, identifier_type_id, :conditions => "voided = 0")
    return if current_occupation and current_occupation.identifier == value
    # TODO BUG: reason is not set
    current_occupation.void! reason unless current_occupation.nil?
    saved = PatientIdentifier.create!(:identifier => value, :identifier_type => identifier_type_id, :patient_id => self.id) rescue false

    unless saved
      identifier = PatientIdentifier.find(:first,
                                          :conditions =>["identifier_type=? AND patient_id=? AND identifier=?",
                                          identifier_type_id,self.id,value]) 
      if identifier
        identifier.voided = 0
        identifier.save
      end  
    end
  end
  
  def patient_location_landmark
    identifier_type_id= PatientIdentifierType.find_by_name("Physical address").patient_identifier_type_id
    value = PatientIdentifier.find_by_patient_id_and_identifier_type(self.id,identifier_type_id, :conditions => "voided = 0")
    return value.identifier if value
  end
  
  def patient_location_landmark=(value)
    identifier_type_id= PatientIdentifierType.find_by_name("Physical address").id
    curr_value = PatientIdentifier.find_by_patient_id_and_identifier_type(self.id,identifier_type_id, :conditions => "voided = 0")
    return if curr_value and curr_value.identifier == value
    curr_value.void! reason if curr_value
    PatientIdentifier.create!(:identifier => value, :identifier_type => identifier_type_id, :patient_id => self.id)
  end
  
  def physical_address
    return PatientAddress.find_by_patient_id(self.id, :conditions => "voided = 0").city_village rescue nil
  end
     
  def Patient.find_by_patient_name(first_name,last_name)
      first_name=first_name.strip[0..0]
      patient_hash = Hash.new
# find all patient name objects that have a given_name or family_name like the value passed in
      # collect thos patient name objects into an array of patient objects
      PatientName.find(:all,:conditions => ["given_name LIKE ? and family_name LIKE ?","#{first_name}%", "#{last_name}%"]).collect{|patient_name| patient_name.patient }.each{ |patient|
  # add the patient objects to the array
       patient_hash[patient.patient_id] = patient
    }
    return patient_hash.values
  end

  def Patient.find_by_patient_names(first_name,other_name,last_name)
      first_name=first_name.strip[0..0]
      other_name=other_name.strip[0..0]
      patient_hash = Hash.new
# find all patient name objects that have a given_name or family_name like the value passed in
      # collect thos patient name objects into an array of patient objects
      PatientName.find(:all,:conditions => ["given_name LIKE ? and family_name LIKE ?","#{first_name}%", "#{last_name}%"]).collect{|patient_name| patient_name.patient }.each{ |patient|
     # add the patient objects to the array
      patient_hash[patient.patient_id] = patient
    }

     # search for patients with other names matching the value passed int
      name_type_id = PatientIdentifierType.find_by_name("Other name").patient_identifier_type_id
      PatientIdentifier.find(:all, :conditions => ["identifier_type = ? AND identifier LIKE ?",name_type_id,"#{other_name}%"]).collect{|patient_identifier| patient_identifier.patient }.each{ |patient|
      # add the patient objects to the hash
      patient_hash[patient.patient_id] = patient
    }
    
    return patient_hash.values
  end 
  
   def Patient.find_by_patient_surname(last_name)
      patient_hash = Hash.new
      # collect thos patient name objects into an array of patient objects
      PatientName.find(:all,:conditions => ["family_name LIKE ?","#{last_name}%"]).collect{|patient_name| patient_name.patient }.each{ |patient|
       # add the patient objects to the array
       patient_hash[patient.patient_id] = patient
    }
       return patient_hash.values
   end

  def validate 
    errors.add(:birthdate, "cannot be in the future") if  self.birthdate > Date.today unless self.birthdate.nil?
  end

=begin 
This seems incompleted, replaced with new method at top
  def Patient.merge(patient1,patient2)
    merged_patient = Patient.new
    merged_patient.fields #TODO
    merged_patient.birthdate #TODO
    merged_patient.birthdate_estimated
    merged_patient_name = PatientName.new
    merged_patient_name.patient = merged_patient
    merged_patient.patient_name #TODO
    merged_patient_address = PatientAddress.new
    merged_patient_address = TODO
    merged_patient_ta = PatientIdentifier.new
    merged_patient_other_name = PatientIdentifier.new
    merged_patient_cell = PatientIdentifier.new
    merged_patient_office = PatientIdentifier.new
    merged_patient_home = PatientIdentifier.new
    merged_patient_occupation = PatientIdentifier.new
    merged_patient_physical_address = PatientIdentifier.new
    merged_patient_national_id = PatientIdentifier.new
    merged_patient_art_guardian #TODO
    merged_patient_filing_number = PatientIdentifier.new
    merged_patient_encounters #TODO
    merged_patient_observations #TODO
  end
=end

  def Patient.total_number_of_patients_registered(program_name = "HIV")
    program = Program.find_by_name(program_name)
    return if program.blank?
    return Patient.find(:all).collect{|patient|
     if patient.patient_programs.collect{|p|p.program.name}.include?(program.name)
       patient
     end
   }.compact.length
  end
  
  def  Patient.today_number_of_patients_with_their_vitals_taken(date = Date.today)
    enc_type=EncounterType.find_by_name("Height/Weight").id
    return Patient.find(:all).collect{|pat|
    if( ! pat.encounters.find_by_type_name("Height/Weight").empty? )
      count= Encounter.count_by_sql "SELECT count(*) FROM encounter where patient_id=#{pat.patient_id} and encounter_type=#{enc_type}  and Date(encounter_datetime) = '#{date}'"
      if count > 0 then
        pat.patient_id
      end
    end
    }.compact.length
  end

  def Patient.return_visits(patient_type,start_date,end_date)
     start_date =start_date.to_date
     end_date = end_date.to_date
     
     case patient_type
       when "Female","Male"
         patients = Patient.find(:all,:conditions => ["(datediff(Now(),birthdate))> (365*15) and gender=?",patient_type])
       when "Under 15 years"
         patients = Patient.find(:all,:conditions => ["(datediff(Now(),birthdate)) <  (365*15)"])
       when "All Patients"
         patients = Patient.find(:all)
     end

     report = Hash.new
     return patients.collect{|pat|
       next unless pat.art_patient?
       pat_obs = Observation.find(:first,:include=>'patient',:conditions => ["Date(obs.obs_datetime) >= ? and Date(obs.obs_datetime) <= ? and obs.patient_id=?",start_date,end_date,pat.patient_id],:order=>"obs.obs_datetime" ,:order=>"obs.obs_datetime desc")
       unless pat_obs.blank?
         report["date_visited"] = pat_obs.obs_datetime 
         report["patient_id"] = pat.national_id
         report["filing_number"] = pat.filing_number
       end
       report
     }.flatten.compact

     return report
  
  end
   
   def Patient.find_patients_adults(patient_type,start_date,end_date)
       
     case patient_type
       when "Female","Male"
         patients=  Patient.find(:all,:conditions => ["(datediff(Now(),birthdate))> (365*15) and gender=?",patient_type])
       when "Under 15 years"
         patients= Patient.find(:all,:conditions => ["(datediff(Now(),birthdate)) <  (365*15)"])
       when "All Patients"
         patients= Patient.find(:all)
     end
     
     return patients.collect{|patient|
       if patient.date_created  >= start_date.to_time and  patient.date_created <= end_date.to_time and patient.art_patient?
         patient
       end
     }.compact
   end
  
  
  def Patient.virtual_register
    #art_location_name = Patient.art_clinic_name(location_id)
    art_location_name = Location.health_center.name
    patient_register=Hash.new
  Observation.find(:all,:group=>"obs.patient_id",:order => "obs_datetime desc").collect{|obs|
    
    hash_key=obs.obs_datetime.strftime("%Y%m%d").to_s + obs.patient_id.to_s
    pat=Patient.find(obs.patient_id) rescue nil
    next if pat.nil?
    if_patient_has_arv_number=pat.ARV_national_id
    next if if_patient_has_arv_number.nil? # this code makes sure that,only patients with arv_numbers are shown
    patient_register[hash_key]= ArtRegisterEntry.new()
    date_started_arts=pat.date_started_art
    patient_register[hash_key].date_of_registration=date_started_arts.strftime("%d %b %Y") unless date_started_arts.nil?
    patient_register[hash_key].quarter=(date_started_arts.month.to_f/3).ceil unless date_started_arts.nil?
    patient_register[hash_key].name = pat.name
    patient_register[hash_key].sex = pat.gender  == "Male" ? "M" : "F"
    patient_register[hash_key].age=pat.age
    patient_address = pat.physical_address
    patient_land_mark = pat.get_identifier("Physical address")
    patient_register[hash_key].address=patient_address.to_s + " /  " + patient_land_mark.to_s unless patient_land_mark.blank? and patient_address.blank?
    patient_register[hash_key].address=patient_address.to_s if !patient_land_mark.blank? and patient_address.blank?
    occupation=pat.occupation
    patient_register[hash_key].occupation= "Not Available"
    patient_register[hash_key].occupation=occupation unless occupation.nil?
    patient_register[hash_key].date_of_visit=pat.patient_visit_date #obs.obs_datetime.strftime("%d-%b-%Y")
    reason =  pat.reason_for_art_eligibility
    unless reason.nil?
      reason_for_starting = reason.name
      reason_for_starting.gsub!(/WHO|adult|child|count/i,"")
      reason_for_starting.gsub!(/stage/i,"Stage")
      patient_register[hash_key].reason_for_starting_arv = reason_for_starting
    end
    art_guardian=pat.art_guardian
    patient_register[hash_key].guardian=art_guardian.name.to_s unless art_guardian.nil?
    patient_register[hash_key].guardian="No guardian" if  patient_register[hash_key].guardian.nil?
    patient_register[hash_key].art_treatment_unit = art_location_name
    patient_register[hash_key].arv_registration_number = pat.ARV_national_id ? pat.ARV_national_id : "MPC number unavailable" 
    patient_register[hash_key].ptb=pat.requested_observation("Pulmonary tuberculosis within the last 2 years")
    patient_register[hash_key].eptb=pat.requested_observation("Extrapulmonary tuberculosis")
    patient_register[hash_key].kaposissarcoma=pat.requested_observation("Kaposi's sarcoma")
    patient_register[hash_key].refered_by_pmtct=pat.requested_observation("Referred by PMTCT")

    outcome_date=""
    
    ["Continue treatment at current clinic","Outcome","Date of positive HIV test","Is at work/school","Date of ART initiation","Is able to walk unaided","ARV regimen","Weight","Peripheral neuropathy","Hepatitis","Skin rash","Lactic acidosis","Lipodystrophy","Anaemia","Whole tablets remaining and brought to clinic"].each{|concept_name|
    patient_observations = Observation.find(:all,:conditions => ["concept_id=? and patient_id=?",(Concept.find_by_name(concept_name).id),pat.patient_id],:order=>"obs.obs_datetime desc").compact
      case concept_name
      when "Continue treatment at current clinic" 
        unless  patient_observations.first.nil?
    outcome=Concept.find_by_concept_id(patient_observations.first.value_coded).name
    outcome="Alive and on ART" if outcome=="Yes"
    patient_register[hash_key].outcome_status=outcome
    patient_register[hash_key].outcome_status.gsub!(/On ART.*/,"On ART")
    outcome_date= patient_observations.first.obs_datetime
    outcome_date=outcome_date.strftime("%Y %b %d")
        else
    patient_register[hash_key].outcome_status="On ART"
        end  
      when "Outcome" 
        unless   patient_observations.first.nil?
         if outcome_date.nil? or (!outcome_date.nil? and  patient_observations.first.obs_datetime.strftime("%Y %b %d")>=outcome_date)
     patient_register[hash_key].outcome_status=Concept.find_by_concept_id(patient_observations.first.value_coded).name

     patient_register[hash_key].outcome_status.gsub!(/Transfer Out.*/,"Transfer out")
         end     
        end  
      when "Date of positive HIV test"
        unless  patient_observations.first.nil?
    patient_register[hash_key].date_first_started_arv_drugs=patient_observations.first.value_datetime.to_date.strftime("%d %b %Y") if patient_observations.first && patient_observations.first.value_datetime
    patient_register[hash_key].date_first_started_arv_drugs ||= Date.new(0,1,1)
        else
    patient_register[hash_key].date_first_started_arv_drugs="Unavailable"
        end 
      when "Is at work/school"
        unless   patient_observations.first.nil?
    patient_register[hash_key].at_work_or_school=Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].at_work_or_school="Unavailable"
        end 
      when "Date of ART initiation"
        unless  patient_observations.first.nil?
    patient_register[hash_key].date_of_art_initiation=patient_observations.first.result_to_string.to_date.strftime("%d %b %Y")
        else
    date_started=pat.date_started_art
    patient_register[hash_key].date_of_art_initiation= date_started.nil? ?  "Unavailable" : date_started.strftime("%d %b %Y")
        end 
      when "Is able to walk unaided"
        unless  patient_observations.first.nil?
    patient_register[hash_key].ambulant=Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].ambulant="Unavailable"
        end 
#data elements pulled at the request of queens
#the register uses a class ArtRegisterEntry to define the various objects of the class
#added objects are: weight and side effects
      when "Weight"
        unless  patient_observations.nil?
      patient_register[hash_key].last_weight = patient_observations.last.blank? || patient_observations.last.value_numeric.nil? ? "Unavailable" :  patient_observations.last.value_numeric
      patient_register[hash_key].first_weight = patient_observations.first.blank? ||patient_observations.first.value_numeric.nil? ? "Unavailable" :  patient_observations.first.value_numeric
        end 
      when "Peripheral neuropathy"
        unless  patient_observations.first.nil?
    patient_register[hash_key].peripheral_neuropathy = Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].peripheral_neuropathy = "Unavailable"
        end 
       when "Hepatitis"
        unless  patient_observations.first.nil?
    patient_register[hash_key].hepatitis=Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].hepatitis="Unavailable"
        end 
       when "Skin rash"
        unless  patient_observations.first.nil?
    patient_register[hash_key].skin_rash=Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].skin_rash="Unavailable"
        end 
       when "Lactic acidosis"
        unless  patient_observations.first.nil?
    patient_register[hash_key].lactic_acidosis = Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].lactic_acidosis = "Unavailable"
        end 
       when "Lipodystrophy"
        unless  patient_observations.first.nil?
    patient_register[hash_key].lipodystrophy=Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].lipodystrophy="Unavailable"
        end 
       when "Anaemia"
        unless  patient_observations.first.nil?
    patient_register[hash_key].anaemia=Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].anaemia="Unavailable"
        end 
       when "Other side effect"
        unless  patient_observations.first.nil?
    patient_register[hash_key].other=Concept.find_by_concept_id(patient_observations.first.value_coded).name
        else
    patient_register[hash_key].other="Unavailable"
        end 
      when "ARV regimen"
        unless  patient_observations.first.nil?
    patient_register[hash_key].arv_regimen=Concept.find_by_concept_id(patient_observations.first.value_coded).short_name
        else
    patient_register[hash_key].arv_regimen="Not available"
        end 
       when "Whole tablets remaining and brought to clinic"
        unless  patient_observations.first.nil?
    patient_register[hash_key].tablets_remaining=patient_observations.first.value_numeric
        else
    patient_register[hash_key].tablets_remaining="Not available"
        end  
      end 
     


    }
      }
    patient_register 
  end
  
  def Patient.art_clinic_name(location_id)
    location_id= Location.find_by_location_id(location_id).parent_location_id
    Location.find_by_parent_location_id(location_id).name
  end

  def requested_observation(name)
    requested_observation = self.observations.find_last_by_concept_name(name)
    return requested_observation="-" if requested_observation.nil?
    requested_observation=requested_observation.result_to_string
    return requested_observation
  end
  
  def requested_observation_by_name_date(name,date)
    requested_observation = self.observations.find_last_by_concept_name_on_date(name,date)
    return requested_observation="-" if requested_observation.nil?
    requested_observation=requested_observation.result_to_string
    return requested_observation
  end
  
  def set_outcome(outcome,date)
  return if outcome.nil? || date.nil?
    encounter = self.encounters.find_first_by_type_name("Update outcome")
    if encounter.blank?
      encounter = Encounter.new
      encounter.patient = self
      encounter.type = EncounterType.find_by_name("Update outcome")
      encounter.encounter_datetime = date
      encounter.provider_id = User.current_user.id
      encounter.save
    end

    obs = Observation.new
    obs.encounter = encounter
    obs.patient = self
    obs.concept = Concept.find_by_name("Outcome")
    obs.value_coded = Concept.find_by_name(outcome).id
    obs.obs_datetime = date
    obs.save
    if outcome == "Died"
      self.death_date = date
      self.save
    end  
  end 
  
## DRUGS
  def set_last_arv_reg(drug_name,prescribe_amount,date)
    return if drug_name.nil?
    encounter = self.encounters.find_by_type_name_and_date("Give drugs",date)
    if encounter.blank?
      encounter = Encounter.new
      encounter.patient = self
      encounter.type = EncounterType.find_by_name("Give drugs")
      encounter.encounter_datetime = date
      encounter.provider_id = User.current_user 
      encounter.save
    else
      encounter = encounter.first 
    end
    
    order=Order.new
    order.order_type_id = OrderType.find_by_name("Give drugs").id
    order.encounter_id = encounter.id
    order.date_created = date
    order.orderer = User.current_user
    order.save

    drug_order = DrugOrder.new
    drug_order.order_id = order.id
    drug_order.quantity=prescribe_amount
    drug_order.drug_inventory_id=Drug.find_by_name(drug_name).id
    drug_order.save
  end
  
## DRUGS
  
  def place_of_first_hiv_test 
    location=self.observations.find_first_by_concept_name("Location of first positive HIV test")
    location_id=location.value_numeric unless location.nil?
    return nil if location_id.nil?
    name = Location.find(location_id).name rescue nil # unless location_id.nil?
    return name  
  end

  def set_hiv_test_location(location_name,date)
    return if location_name.nil?
    date = Time.now if date.blank?
    encounter_name = self.encounters.find_first_by_type_name("HIV Staging")
    if encounter_name.nil?
      encounter_name = Encounter.new
      encounter_name.patient = self
      encounter_name.type = EncounterType.find_by_name("HIV Staging")
      encounter_name.encounter_datetime = date
      encounter_name.provider_id = User.current_user.id
      encounter_name.save
    end

    obs = Observation.new
    obs.encounter = encounter_name
    obs.patient = self
    obs.concept = Concept.find_by_name("Location of first positive HIV test")
    lacation_id=Location.find_by_name(location_name).id
    location_id = Location.find_by_sql("select location_id from location where name like \"%#{location_name}%\"")[0].location_id if location_id.nil?
    obs.value_numeric=location_id
    obs.obs_datetime = date
    obs.save
  end
  
  def guardian_present?(date=Date.today)
      encounter = self.encounters.find_by_type_name_and_date("HIV Reception", date).last
      guardian_present=encounter.observations.find_last_by_concept_name("Guardian present").to_s unless encounter.nil?

      return false if guardian_present.blank?
      return false if guardian_present.match(/No/)
      return true
  end
  
  def patient_present?(date=Date.today)
      encounter = self.encounters.find_by_type_name_and_date("HIV Reception", date).last
      patient_present=encounter.observations.find_last_by_concept_name("Patient present").to_s unless encounter.nil?

      return false if patient_present.blank?
      return false if patient_present.match(/No/)
      return true
  end
  
  def patient_and_guardian_present?(date=Date.today)
      patient_present = self.patient_present?(date)
      guardian_present = self.guardian_present?(date)

      return false if !patient_present || !guardian_present
      return true
  end
   
  def update_pmtct
    pat_nat_id = FasterCSV.read("/home/bond/Desktop/PatID_pmtct2.csv")
    pat_id = pat_nat_id.collect{|pat|Patient.find_by_national_id(pat)}
    pmtct_obs = pat_id.collect{|pat|pat.observations.find_by_concept_name("Referred by PMTCT").collect{|obs|obs.value_coded = "3"}}
    pmtct_obs.save!
  end 
  
  def patient_visit_date
    enc_type_id =EncounterType.find_by_name("HIV Reception").id
    enc_type = Encounter.find(:all,:conditions=>["patient_id=? and encounter_type=?",self.patient_id,enc_type_id],:order=>"encounter_datetime DESC")
    unless enc_type.blank?
      return enc_type.first.encounter_datetime
    else
      return nil
    end
  end
 
  def get_cohort_visit_data(start_date=nil, end_date=nil)
    cohort_visit_data = Hash.new

    self.staging_encounter.observations.each{ |o|         
        cohort_visit_data[o.concept.name] = o.value_coded == 3 # 3 is the concept_id for 'Yes'
    } rescue nil
    
    return cohort_visit_data
  end 

=begin
  def get_cohort_visit_data(start_date=nil, end_date=nil)
    start_date = Encounter.find(:first, :order => "encounter_datetime").encounter_datetime.to_date if start_date.nil?
    end_date = Date.today if end_date.nil?

    last_year_in_quarter = end_date.year
    if end_date.month != end_date.next.month
      last_month_in_quarter = end_date.month
    else
      last_month_in_quarter = end_date.month - 1
      if last_month_in_quarter == 0
        last_month_in_quarter = 12
        last_year_in_quarter -= 1
      end
    end
  
    # in Reports::CohortByRegistration, we now only need Staging data from this method
    patient_encounters = Encounter.find(:all,
      :joins => "INNER JOIN obs on obs.encounter_id = encounter.encounter_id AND obs.voided = 0", 
      :conditions => ["encounter.patient_id = ? AND encounter.encounter_type = ? AND 
                       encounter_datetime >= ? AND encounter_datetime <= ?", 
                       self.id, EncounterType.find_by_name('HIV Staging').id,(start_date.to_s + ' 00:00:00').to_datetime, 
                       (end_date.to_s + ' 23:59:59').to_datetime], 
      :order => "encounter_datetime DESC")
    cohort_visit_data = Hash.new
    followup_done = true #false
    staging_done = false
    pill_count_done = true #false

    total_encounters = patient_encounters.length
    i = 0
    while i < total_encounters
      this_encounter = patient_encounters[i]
      cohort_visit_data["last_encounter_datetime"] = this_encounter.encounter_datetime if i == 0
      cohort_visit_data["Last month"] = last_month_in_quarter
      this_encounter_observations = this_encounter.observations

      if this_encounter.name == "HIV Staging" and not staging_done
        this_encounter_observations.each{ |o| 
          this_concept = o.concept.name
          if this_concept == "CD4 count"
            cohort_visit_data[this_concept] = o.value_numeric
          elsif this_concept == "CD4 test date"
            cohort_visit_data[this_concept] = o.obs_datetime
          else
            cohort_visit_data[this_concept] = o.value_coded == 3 # 3 is the concept_id for 'Yes'
          end
        }
        staging_done = true
      end

      break if followup_done and staging_done and pill_count_done
      i += 1
    end
    return cohort_visit_data
  end 
=end
  def is_dead?
    self.outcome_status == "Died"
  end  
  
  def last_visit_date(date)
    number_of_months =(Date.today - date).to_i
    number_of_months/30
  end  

  def remove_first_relationship(relationship_name="ART Guardian") 
    guardian_type = RelationshipType.find_by_name(relationship_name)
    person = self.people[0]
    rel = Relationship.find(:first, :conditions => ["voided = 0 AND relationship = ? AND person_id = ?", guardian_type.id, person.id], :order => "date_created DESC") unless person.nil?
   if rel
    rel.void! "Modifying Mastercard" 
    self.reload
   end 
  end

  def national_id_label(num = 1)
    print_new_national_id = GlobalProperty.find_by_property("print_new_national_id").property_value rescue "false"
    return self.new_national_id_label if print_new_national_id == "true"
    self.set_national_id unless self.national_id
    birth_date = self.birthdate_for_printing
    sex =  self.gender == "Female" ? "(F)" : "(M)"
    national_id_and_birthdate=self.print_national_id  + " " + birth_date
    ta = self.traditional_authority
    ta = ta.strip[0..21].humanize.delete("'") unless ta.blank?

    label = ZebraPrinter::StandardLabel.new
    label.draw_barcode(40, 180, 0, 1, 5, 15, 120, false, "#{self.national_id}")    
    label.draw_text("#{self.name.titleize}", 40, 30, 0, 2, 2, 2, false)           
    label.draw_text("#{national_id_and_birthdate}#{sex}", 40, 80, 0, 2, 2, 2, false)        
    label.draw_text("TA: #{ta}", 40, 130, 0, 2, 2, 2, false)
    label.print(num)
  end

  def new_national_id_label(num = 1)
    self.set_new_national_id unless self.new_national_id
    new_national_id = self.new_national_id
    birth_date = self.birthdate_for_printing
    sex =  self.gender == "Female" ? "(F)" : "(M)"
    national_id_and_birthdate= new_national_id[0..2] + "-" + new_national_id[3..-1]  + " " + birth_date
    ta = self.traditional_authority
    ta = ta.strip[0..21].humanize.delete("'") unless ta.blank?

    label = ZebraPrinter::StandardLabel.new
    label.draw_barcode(40, 180, 0, 1, 5, 15, 120, false, "#{self.new_national_id}")    
    label.draw_text("#{self.name.titleize}", 40, 30, 0, 2, 2, 2, false)           
    label.draw_text("#{national_id_and_birthdate}#{sex}", 40, 80, 0, 2, 2, 2, false)        
    label.draw_text("TA: #{ta}", 40, 130, 0, 2, 2, 2, false)
    label.print(num)
  end

  def filing_number_label(num = 1)
    file=self.filing_number
    file_type=file.strip[3..4]
    version_number=file.strip[2..2]
    number = Patient.print_filing_number(file)

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("#{number}",75, 30, 0, 4, 4, 4, false)            
    label.draw_text("Filing area #{file_type}",75, 150, 0, 2, 2, 2, false)            
    label.draw_text("Version number: #{version_number}",75, 200, 0, 2, 2, 2, false)            
    label.print(num)
  end

  def transfer_out_label(date = Date.today,destination="Unknown")
    who_stage = self.reason_for_art_eligibility 
    initial_staging_conditions = self.art_initial_staging_conditions
   
    label = ZebraPrinter::Label.new(776, 329, 'T')
    label.line_spacing = 0
    label.top_margin = 30
    label.bottom_margin = 30
    label.left_margin = 25
    label.x = 25
    label.y = 30
    label.font_size = 3
    label.font_horizontal_multiplier = 1
    label.font_vertical_multiplier = 1
   
    # 25, 30
    # Patient personanl data 
    label.draw_multi_text("#{Location.current_health_center} transfer out label", {:font_reverse => true})
    label.draw_multi_text("From #{Location.current_arv_code} to #{destination}", {:font_reverse => false})
    label.draw_multi_text("ARV number: #{self.arv_number}", {:font_reverse => true})
    label.draw_multi_text("Name: #{self.name} (#{self.sex.first})\nAge: #{self.age}", {:font_reverse => false})

    # Print information on Diagnosis!
    label.draw_multi_text("Diagnosis", {:font_reverse => true})
    label.draw_multi_text("Reason for starting: #{self.reason_for_art_eligibility}", {:font_reverse => false})
    label.draw_multi_text("Art start date: #{self.date_started_art.strftime("%d-%b-%Y") rescue nil}", {:font_reverse => false})
    label.draw_multi_text("Other diagnosis:", {:font_reverse => true})
# !!!! TODO
    staging_conditions = ""
    count = 1
    initial_staging_conditions.each{|condition|
     staging_conditions+= " (#{count+=1}) " unless staging_conditions.blank?
     staging_conditions= "(#{count}) " if staging_conditions.blank?
     staging_conditions+=condition
    }
    label.draw_multi_text("#{staging_conditions}", {:font_reverse => false})

    # Print information on current status of the patient transfering out!
    work = self.observations.find_last_by_concept_name("Is at work/school").to_short_s rescue nil
    amb = self.observations.find_last_by_concept_name("Is able to walk unaided").to_short_s rescue nil
    first_cd4_count = self.observations.find_first_by_concept_name("CD4 count")
    last_cd4_count = self.observations.find_last_by_concept_name("CD4 count")
    last_cd4 = "Last CD4: " + last_cd4_count.obs_datetime.strftime("%d-%b-%Y") + ": " + last_cd4_count.to_short_s.delete("=,Yes") rescue nil
    first_cd4 = "First CD4: " + first_cd4_count.obs_datetime.strftime("%d-%b-%Y") + ": " + first_cd4_count.to_short_s.delete("=,Yes") rescue nil
    label.draw_multi_text("Current Status", {:font_reverse => true})
    label.draw_multi_text("#{work} #{amb}", {:font_reverse => false})
    label.draw_multi_text("#{first_cd4}", {:font_reverse => false})
    label.draw_multi_text("#{last_cd4}", {:font_reverse => false})
 
    # Print information on current treatment of the patient transfering out!
    current_drugs = self.previous_art_drug_orders
    current_art_drugs = current_drugs.collect{|drug_name_quantity|drug_name_quantity.to_s} rescue nil
    current_art_drugs = current_art_drugs.collect{|drug_name|drug_name.split(":")[0]} rescue nil
    drug_names = ""
    count = 1
    current_art_drugs.each{|name|
     drug_names+= " (#{count+=1}) " unless drug_names.blank?
     drug_names= "(#{count}) " if drug_names.blank?
     drug_names+=name
    } rescue nil

    start_date = self.date_started_art.strftime("%d-%b-%Y") rescue nil
    label.draw_multi_text("Current art drugs", {:font_reverse => true})
    label.draw_multi_text("#{drug_names}", {:font_reverse => false})
    label.draw_multi_text("Transfer out date:", {:font_reverse => true})
    label.draw_multi_text("#{date.strftime("%d-%b-%Y")}", {:font_reverse => false})

    label.print(1)
  end
  
  def archived_filing_number_label(num=1)
    patient_id = PatientIdentifier.find(:first, :conditions => ["voided = 1 AND identifier = ? AND patient_id <> ?",self.filing_number,self.id]).patient_id rescue nil
    return nil if patient_id.blank?
    patient = Patient.find(patient_id) #find the patient who have given up his/her filing number
    filing_number = patient.archive_filing_number
    return nil if filing_number.blank?

    file= filing_number
    file_type=file.strip[3..4]
    version_number=file.strip[2..2]
    number= Patient.print_filing_number(file) 
    old_filing_number =  self.filing_number[5..-1].to_i.to_s rescue nil
    
    label = ZebraPrinter::StandardLabel.new
    label.draw_text("#{number}",75, 30, 0, 4, 4, 4, true)            
    label.draw_text("#{Location.current_arv_code} archive filing area",75, 150, 0, 2, 2, 2, false)            
    label.draw_text("Version number: #{version_number}",75, 200, 0, 2, 2, 2, false)            
    return label.print(num)
  end
  
  def self.print_filing_number(number)
   len = number.length - 5
   return number[len..len] + "   " + number[(len + 1)..(len + 2)]  + " " +  number[(len + 3)..(number.length)]
  end

## DRUGS
  def drug_dispensed_label(date=Date.today)
    return self.mastercard_visit_label(date)
=begin
    summary_visit_label = GlobalProperty.find_by_property("use_new_summary_visit_label").property_value rescue "false"
    return self.mastercard_visit_label(date) if summary_visit_label == "true"
=end    
    date=date.to_date
    sex =  self.gender == "Female" ? "(F)" : "(M)"
    next_appointment = self.next_appointment_date(date)
    next_appointment_date="Next visit: #{next_appointment.strftime("%d-%b-%Y")}" unless next_appointment.nil?
    symptoms = Array.new
    weight=nil
    height=nil
    prescription = DrugOrder.given_drugs_dosage(self.drug_orders_for_date(date))
    amb=nil
    work_sch=nil

    concept_names = Concept.find_by_name('Symptoms').answer_options.collect{|option| option.name}
    concept_names += Concept.find_by_name('Symptoms continued..').answer_options.collect{|option| option.name}
    concept_names += ["Weight","Height","Is at work/school","Is able to walk unaided"]
    concept_names.each{|concept_name|
      concept = Concept.find_by_name(concept_name)
      patient_observations = Observation.find(:all,:conditions => ["concept_id=? and patient_id=? and Date(obs.obs_datetime)=? and voided =0",concept.id,self.patient_id,date.to_date.strftime("%Y-%m-%d")],:order=>"obs.obs_datetime desc")
      case concept_name
        when "Is able to walk unaided"
          unless  patient_observations.first.nil?
            amb=patient_observations.first.answer_concept.name
            amb == "Yes" ? amb = "walking;" : amb = "not walking;"
          end
        
        when "Is at work/school"
          unless   patient_observations.first.nil?
            work_sch=patient_observations.first.answer_concept.name
            work_sch == "Yes" ? work_sch = "working;" : work_sch = "not working;"
          end

        when "Weight"
          weight=patient_observations.first.value_numeric.to_s + "kg;" unless patient_observations.first.nil?

        when "Height"
          height=patient_observations.first.value_numeric.to_s + "cm; " unless patient_observations.first.nil?

        else
          unless patient_observations.first.nil?
            ans = patient_observations.first.answer_concept.name
            symptoms << concept.short_name if ans.include?("Yes") # 'Yes', 'Yes unknow cause', 'Yes drug induced'
          end
      end
    }

   height ||= ""
   provider = self.encounters.find_by_type_name_and_date("ART Visit", date)
   provider_name = provider.last.provider.username rescue nil
   prescride_drugs = Hash.new()
   prescride_drugs = Patient.addup_prescride_drugs(prescription)
   visit_by="Both patient and guardian visit" if self.patient_and_guardian_present?(date)
   visit_by="Patient visit" if visit_by.blank? and self.patient_present?(date) and !self.guardian_present?(date)
   visit_by="Guardian visit" if visit_by.blank? and self.guardian_present?(date) and !self.patient_present?(date)
   provider_name = User.current_user.username if provider_name.blank?
   symptoms = symptoms.reject{|s|s.blank?}
   symptoms.length > 0 ? symptom_text = symptoms.join(', ') : symptom_text = 'no symptoms;'
   adherence = ""#self.adherence_report(previous_visit_date)
   drugs_given = prescride_drugs.to_s rescue nil
   
   current_outcome = Patient.visit_summary_out_come(self.outcome.name) rescue nil
   patient_regimen = self.patient_historical_regimens.first.concept.name rescue nil

   label = ZebraPrinter::StandardLabel.new
   label.font_size = 3
   label.number_of_labels = 2
   label.draw_multi_text("#{self.name} (#{self.sex.first}) #{self.print_national_id}",{:font_reverse =>false})
   label.draw_multi_text("#{date.strftime("%d-%b-%Y")} #{visit_by} (#{provider_name.upcase})",{:font_reverse =>false})
   label.draw_multi_text("Vitals: #{height}#{weight} #{amb} #{work_sch} #{symptom_text} #{adherence}",{:font_reverse =>false, :hanging_indent => 8})
   label.draw_multi_text("Drugs:#{drugs_given}",{:font_reverse =>false})
#Print next appointment date if the patient is on standard regimen
   if (patient_regimen == 'Stavudine Lamivudine Nevirapine Regimen')
    label.draw_multi_text("#{next_appointment_date}",{:font_reverse => false}) 
   end
   unless current_outcome.blank?
     label.draw_multi_text("Outcome: #{current_outcome}",{:font_reverse => false}) if !current_outcome.include?("On ART")
   end
   return label.print(1)
  end
  
  def self.visit_summary_out_come(outcome)
    return if outcome.blank?
    return "On ART at #{Location.current_arv_code}" if outcome == "On ART"
    return outcome
  end
   
## DRUGS
  def self.addup_prescride_drugs(prescriptions)
   return if prescriptions.blank?
   prescribe_drugs=Hash.new()
   prescriptions.each{|prescription|
    (drug_name, frequency, dose_amount,drug_quantity) =  prescription.split(/, */)
    prescribe_drugs[drug_name] = {"Morning" => 0, "Noon" => 0, "Evening" => 0, "Amount" => drug_quantity} if prescribe_drugs[drug_name].nil?
    prescribe_drugs[drug_name].keys.each{ |time|
     prescribe_drugs[drug_name][time] += dose_amount.to_f if frequency.match(/#{time}/i)
    }
   }


   drugs_given = Array.new()
   prescribe_drugs.each do |drug_name,dosing_frequency|
    #dosage = self.print_dosage(dosing_frequency)
    #drugs_given += "#{drug_name} (#{dosing_frequency["Morning"]} - #{dosing_frequency["Noon"]} - #{dosing_frequency["Evening"]})\n"
    drugs_given << "\n- #{drug_name}: (#{dosing_frequency['Amount']})" 
    #drugs_given << " #{drug_name} #{dosage};" 
   end
   return drugs_given.uniq.sort
  end

  def self.print_dosage(dosing_frequency)
    return nil
    dosage_results = Array.new()
    morning = dosing_frequency["Morning"].to_s
    noon = dosing_frequency["Noon"].to_s
    evening = dosing_frequency["Evening"].to_s

    morning = morning[-2..morning.length] == ".0" ? morning[0..-3] : morning
    noon = noon[-2..noon.length] == ".0" ? noon[0..-3] : noon
    evening = evening[-2..evening.length] == ".0" ?  evening[0..-3] : evening


    return "( _ - _ - _ )" if morning == "0" and noon == "0" and evening == "0"
    ("(#{self.to_fraction(morning)} - #{self.to_fraction(noon)} - #{self.to_fraction(evening)})\n")
  end

  def self.to_fraction(number)
    return number if !number.include?(".")
    whole_number = number.split(".").first
    decimal_number = "0.#{number.split(".").last}"
    return "(#{decimal_number.to_f.to_r.to_s})" if whole_number == "0"
    "#{whole_number} (#{decimal_number.to_f.to_r.to_s})"
  end

  def initial_weight
     initial_weight = self.observations.find_first_by_concept_name("Weight")
     return initial_weight.value_numeric unless initial_weight.nil? 
  end

  def set_initial_weight(weight, date)
    weight = weight.to_f
    raise "Patient already has initial_weight" unless self.initial_weight.nil?
    observation = Observation.new
    observation.patient = self
    observation.concept = Concept.find_by_name("Weight")
    observation.value_numeric = weight
    observation.obs_datetime = date
    observation.save
  end

  def initial_height
     initial_height = self.observations.find_first_by_concept_name("Height")
     return initial_height.value_numeric unless initial_height.nil? 
  end

  def set_initial_height(height, date)
    height = height.to_f
    raise "Patient already has initial_height" unless self.initial_height.nil?
    observation = Observation.new
    observation.patient = self
    observation.concept = Concept.find_by_name("Height")
    observation.value_numeric = height
    observation.obs_datetime = date
    observation.save
  end

  def current_place_of_residence
    return self.person_address
  end

  def current_place_of_residence=(name)
    patient_current_addresses = self.patient_addresses.collect{|add|add unless add.voided}.compact rescue []
    patient_current_addresses.each{|add|
      add.voided = 1
      add.date_voided = Time.now()
      add.voided_by = User.current_user.id
      add.save
    }
    patient_addresses = PatientAddress.new()
    patient_addresses.patient = self
    patient_addresses.city_village = name
    patient_addresses.save
	end
	  
  def set_existing_national_id(national_id)
	  return if self.national_id
	  identifier_type = PatientIdentifierType.find_by_name("National id")
	  return nil if identifier_type.blank?
    num_already_given = PatientIdentifier.find(:first,
                        :conditions =>["identifier_type=? AND voided=0 AND identifier=?",
                        identifier_type.id,national_id])
    if num_already_given
      self.set_national_id ; return
    end  
	  PatientIdentifier.create!(:identifier => national_id, :identifier_type => identifier_type.id, :patient_id => self.id)
  end
    
	def set_national_id
	  return if self.national_id
    print_new_ids = GlobalProperty.find_by_property("print_new_national_id").property_value == 'true' rescue false
    return self.set_new_national_id if print_new_ids
	  identifier_type = PatientIdentifierType.find_by_name("National id")
	  return nil if identifier_type.blank?
	  PatientIdentifier.create!(:identifier => Patient.next_national_id, :identifier_type => identifier_type.id, :patient_id => self.id)
  end
  
	def set_new_national_id
	  return if self.new_national_id
	  identifier_type = PatientIdentifierType.find_by_name("New national id")
	  return nil if identifier_type.blank?
	  PatientIdentifier.create!(:identifier => PatientNationalId.next_id(self.id), 
      :identifier_type => identifier_type.id, 
      :patient_id => self.id)
  end
  
  def self.next_filing_number
   return PatientIdentifier.get_next_patient_identifier("Filing number")
  end
 
  def self.next_archive_filing_number
   return PatientIdentifier.get_next_patient_identifier("Archived filing number")
  end 
   
  def needs_filing_number?
   if self.filing_number
    return true if self.archive_filing_number
     return false
    else
     return true 
   end
  end

  def set_filing_number
    return unless self.needs_filing_number?
    filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing number")

    if self.archive_filing_number 
     #voids the record- if patient has a dormant filing number
       archive_identifier_type = PatientIdentifierType.find_by_name("Archived filing number").id
       current_archive_filing_numbers = self.patient_identifiers.collect{|identifier|
                                       identifier if identifier.identifier_type==archive_identifier_type and identifier.voided==false
                                     }.compact
       current_archive_filing_numbers.each{|filing_number|                                
         filing_number.voided = 1
         filing_number.void_reason = "patient assign new active filing number"
         filing_number.voided_by = User.current_user.id
         filing_number.date_voided = Time.now()
         filing_number.save
       }  
    end

    next_filing_number = Patient.next_filing_number # gets the new filing number! 
    next_patient_to_archived = Patient.next_filing_number_to_be_archived(next_filing_number) # checks if the the new filing number has passed the filing number limit...

    unless next_patient_to_archived.blank?
     Patient.archive_patient(next_patient_to_archived,self) # move dormant patient from active to dormant filing area
     next_filing_number = Patient.next_filing_number # gets the new filing number!
    end

    filing_number= PatientIdentifier.new() 
    filing_number.patient_id = self.id
    filing_number.identifier_type = filing_number_identifier_type.patient_identifier_type_id
    filing_number.identifier = next_filing_number
    filing_number.save

  end

  def set_archive_filing_number
   return if self.archive_filing_number
   archive_number = Patient.next_archive_filing_number 
   new_archive_number = PatientIdentifier.new()
   new_archive_number.patient = self
   new_archive_number.identifier_type = PatientIdentifierType.find_by_name("Archived filing number").id
   new_archive_number.date_created = Time.now()
   new_archive_number.creator = User.current_user.id
   new_archive_number.identifier = archive_number
   new_archive_number.save
  end
  
  def self.next_filing_number_to_be_archived(filing_number)
    global_property_value = GlobalProperty.find_by_property("filing_number_limit").property_value rescue "4000"

    if (filing_number[5..-1].to_i >= global_property_value.to_i)
      all_filing_numbers = PatientIdentifier.find(:all, :conditions =>["identifier_type = ? and voided= 0",
                           PatientIdentifierType.find_by_name("Filing number").id],:group=>"patient_id")
      patient_ids = all_filing_numbers.collect{|i|i.patient_id}
      return Encounter.find_by_sql(["
        SELECT patient_id, MAX(encounter_datetime) AS last_encounter_id
        FROM encounter 
        WHERE patient_id IN (?)
        AND encounter_type < 13 
        GROUP BY patient_id
        ORDER BY last_encounter_id
        LIMIT 1",patient_ids]).first.patient_id rescue nil 
    end
  end

  def Patient.archive_patient(patient_to_be_archived_id,current_patient)
    patient = Patient.find(patient_to_be_archived_id)
    filing_number_identifier_type = PatientIdentifierType.find_by_name("Archived filing number")
    next_filing_number = Patient.next_archive_filing_number

    filing_number= PatientIdentifier.new() 
    filing_number.patient = patient 
    filing_number.identifier_type = filing_number_identifier_type.patient_identifier_type_id  
    filing_number.identifier = next_filing_number
    filing_number.save

   #void current filing number
    current_filing_numbers =  PatientIdentifier.find(:all,:conditions=>["patient_id=? and identifier_type=? and voided = 0",patient.id,PatientIdentifierType.find_by_name("Filing number").id])
    current_filing_numbers.each{|filing_number|
       filing_number.voided = 1
       filing_number.voided_by = User.current_user.id
       filing_number.void_reason = "Archived"
       filing_number.date_voided = Time.now()
       filing_number.save
    }
   
    #the following code creates an encounter so that the the current patient
    #being given a new active filing number should have a new encounter with
    #the current date_time!!
    #the "current encounter date_time" will ensure that the patients' latest
    #encounter_datetime is "up to date"....
    new_number_encounter = Encounter.new()
    new_number_encounter.patient_id = current_patient.id
    new_number_encounter.encounter_type = EncounterType.find_by_name("Barcode scan").id
    new_number_encounter.encounter_datetime = Time.now()
    new_number_encounter.provider_id = User.current_user.id
    new_number_encounter.creator = User.current_user.id
    new_number_encounter.save!

  end

  def self.next_national_id
    health_center_id = GlobalProperty.find_by_property("current_health_center_id").property_value
    national_id_version="1"
    national_id_prefix = "P#{national_id_version}#{health_center_id.rjust(3,"0")}"

    national_id_type = PatientIdentifierType.find_by_name("National id").patient_identifier_type_id

    last_national_id = PatientIdentifier.find(:first,:order=>"identifier DESC", 
      :conditions => ["voided = 0 AND identifier_type = ? AND left(identifier,5) = ?
      AND LENGTH(identifier) = 13", national_id_type , national_id_prefix])

    unless last_national_id.blank?
       last_national_id_number = last_national_id.identifier
    else
       last_national_id_number = "0"
    end

    next_number = (last_national_id_number[5..-2].to_i+1).to_s.rjust(7,"0") 
    new_national_id_no_check_digit = "#{national_id_prefix}#{next_number}"
    check_digit = PatientIdentifier.calculate_checkdigit(new_national_id_no_check_digit[1..-1])
    return "#{new_national_id_no_check_digit}#{check_digit}" 
  end

  def Patient.validates_national_id(number)
   number_to_be_checked = number[0..11]
   check_digit = number[-1..-1].to_i
   valid_check_digit =PatientIdentifier.calculate_checkdigit(number_to_be_checked)
   return "id should have 13 characters" if number.length != 13
   return "valid id" if valid_check_digit == check_digit
   return "check digit is wrong" if valid_check_digit != check_digit and number.match(/\d+/).to_s.length == 12
   return "invalid id"
  end

  def landmark
    self.patient_location_landmark
  end

  def landmark=(value)
    self.patient_location_landmark=(value)
  end

  def hiv_test_date
    date_of_first_positive_hiv_test = self.observations.find_by_concept_name("Date of positive HIV test")
    date_of_first_positive_hiv_test.first.value_datetime unless date_of_first_positive_hiv_test.empty?
  end

  def set_hiv_test_date(date)
    observation = Observation.new
    observation.patient = self
    observation.concept = Concept.find_by_name("Date of positive HIV test")
    observation.value_datetime = date
    observation.obs_datetime = Date.today
    observation.save
  end

  def sex=(sex)
    self.gender = sex
  end

  def sex
    self.gender
  end

  def void(reason)
    # make sure User.current_user is set
    self.voided = true
    self.voided_by = User.current_user.id unless User.current_user.nil?
    self.void_reason = reason
    self.save
  end
 
    #HL7 elements
  def facility
   return GlobalProperty.find(:all, :conditions =>["property = ?","current_health_center_id"]).first.property_value
  end

  def to_patient_hl7
    require 'ruby-hl7'
    require 'socket'

    # create the empty hl7 message
    msg = HL7::Message.new

    # create an empty MSH segment
    msh = HL7::Message::Segment::MSH.new 
    evn = HL7::Message::Segment::EVN.new 
    pid = HL7::Message::Segment::PID.new 
    pv1 = HL7::Message::Segment::PV1.new 
    obr = HL7::Message::Segment::OBR.new 
    obx = HL7::Message::Segment::OBX.new

    # create an empty NTE segment
   # nte = HL7::Message::Segment::NTE.new
    msg << msh # add the MSH segment to our message
    #msg << nte  # add the NTE segment to our message
   
    # let's fill in some fields using pre-defined aliases
    msh.enc_chars = "^~\&"
    msh.sending_app = "Baobab Health partenership"
    msh.sending_facility = GlobalProperty.find(:all, :conditions =>["property = ?","current_health_center_id"]).first.property_value
    msh.recv_facility = "MOH"
    msh.recv_app = "0999"
    msh.date =  Date.today
    msh.message_type = "ZMW^P01^ZMW_P01"
    msh.time =  Time.now()
   # msh.message_control_id = ""
    msh.processing_id = "PT"
    msh.version_id = "2.5"
    msh.country_code = "MWI"
    msh.charset = "UTF-8"
    msh.principal_language_of_message = "English"

    #nte.comment = "my message rocks, ruby-hl7 is great"

    # let's create our own on-the-fly segment (NK1 is not implemented in code)
    seg = HL7::Message::Segment::Default.new
    seg.e0 = "SFT"             # define the segment's name
    seg.e1 = "Baobab Health partnerhip"   # define it's first field
    seg.e2 = "1.000" # define it's second field
    seg.e3 = "Baobab Anti-retroviral system" # define it's second field
    seg.e4 = "Binary ID" # define it's second field
    seg.e5 = "Installation Date"
    
   # patient_obj = self

    msg << seg  # add the new segment to the message
    msg << evn  # add the new segment to the message
    msg << pid  # add the new segment to the message
 
    evn.recorded_date = Date.today
    evn.event_facility = GlobalProperty.find(:all, :conditions =>["property = ?","current_health_center_id"]).first.property_value
     
    pid.set_id = "1"
    pid.patient_id = self.patient_id
    pid.patient_id_list = self.patient_id 
    pid.patient_name = self.name 
    pid.patient_dob = self.birthdate.year
    
    if self.gender == "Male"
     pid.admin_sex = "M"
    else
     pid.admin_sex = "F"
    end  
    
    pid.address = self.patient_addresses.last.city_village
    pid.phone_home = self.get_identifier("Home phone number")
    pid.death_date = self.death_date
  
    if self.outcome_status == "Died"
      pid.death_indicator = "D"
    else
      pid.death_indicator = "N"
    end
    
    nk1 = HL7::Message::Segment::Default.new
    nk1.e0 = "NK1"
    nk1.e1 = "1"
    nk1.e2 = self.art_guardian.name
    
    msg << nk1

    #patient visit information; including observations
    #aggregate visits
    #should visits be broken down into one visit
    #HL7 definition says that definition is based on 
        visit_number = 1
        encounter_dates = self.encounters.collect{|e|e.encounter_datetime.to_date}.uniq 
        first_encounter = encounter_dates.reverse.pop
        pv1.set_id = visit_number
        pv1.assigned_location =  GlobalProperty.find(:all, :conditions =>["property = ?","current_health_center_id"]).first.property_value
        pv1.admit_date = first_encounter.strftime("%Y%m%d")
        
        msg << pv1

    encounter_dates.each{|ed|
     visit_number += 1
     pv1.set_id = visit_number 
     pv1.assigned_location =  GlobalProperty.find(:all, :conditions =>["property = ?","current_health_center_id"]).first.property_value
     pv1.admit_date = ed.strftime("%Y%m%d")
     msg << pv1
       self.encounters.find_by_date(ed).each{|encounter| 
        obr.set_id = visit_number
        obr.universal_service_id = "CurrentART"
        obr.observation_date = ed
        msg << obr
        #Weight  
        obx.set_id = visit_number
        obx.value_type = "NM"
        obx.observation_id ="18833-4"
        obx.observation_value = encounter.find_by_type_name("Height/Weight").observations.find_by_concept_name("Weight")
        obx.units = "KG"
        obx.observation_result_status = "F"
        obx.observation_date = encounter.find_by_type_name("Height/Weight").observations.find_by_concept_name("Weight").obs_datetime.strftime("%Y%m%d")
        #Height
        obx.set_id = visit_number + 1
        obx.value_type = "NM"
        obx.observation_id = "K00237"
        obx.observation_value = encounter.find_by_type_name("Height/Weight").observations.find_by_concept_name("Height")
        obx.units = "cm"
        obx.observation_result_status = "F"
        obx.observation_date = encounter.find_by_type_name("Height/Weight").observations.find_by_concept_name("Height").obs_datetime.strftime("%Y%m%d")
        obx.set_id = visit_number + 2
        obx.value_type = ""
        obx.observation_id = "K00201^ART Prior Treatment"
        obx.observation_value = encounter.find_by_type_name("HIV First visit").observations.find_by_concept_name("Ever received ART")
        
        
       }
     }

    puts msg
 
  end  
  
  
     
  def complete_visit?(date = Date.today)
    encounter_types_for_day = self.encounters.find_by_date(date).collect{|encounter|encounter.name}
    expected_encounter_types = ["ART Visit", "Give drugs", "HIV Reception", "Height/Weight"]
    return true if (expected_encounter_types - encounter_types_for_day).empty?

    puts encounter_types_for_day.join(", ") unless encounter_types_for_day.blank? #some days will not have any encounters.
    return false
  end

  #HL7 functions
  #HL7 functions
 def weight_on_date(date = Date.today)  
  begin
       weight = self.encounters.find_by_type_name_and_date("Height/Weight",date).first.observations.find_by_concept_name("Weight").first.value_numeric
    rescue ActiveRecord::RecordNotFound
        return nil
    end 
        return weight
  end	  

  def height_on_date(date = Date.today)
    begin
       height = self.encounters.find_by_type_name_and_date("Height/Weight",date).first.observations.find_by_concept_name("Height").first.value_numeric
    rescue ActiveRecord::RecordNotFound
        return nil
    end 
        return height
  end	  

   def ever_received_art
    hiv_first_visit = self.encounters.find_first_by_type_name("HIV First visit")
   begin 
    yes_concept = Concept.find_by_name("Yes")
    prior_art = hiv_first_visit.observations.find_last_by_concept_name("Ever received ART").answer_concept == yes_concept
    return "Prior ARV treatment" if prior_art == yes_concept
   rescue	    
    return "No prior ARV treatment"
   end 
  end

  def district_of_initiation
    return false unless self.hiv_patient?
    hiv_first_visit = self.encounters.find_first_by_type_name("HIV First visit")
    return false if hiv_first_visit.blank?
  #not a transfer in, therefore default district to location of test
    if  hiv_first_visit.observations.find_last_by_concept_name("Ever received ART").nil? or  hiv_first_visit.observations.find_last_by_concept_name("Ever registered at ART clinic").blank?
     return self.encounters.find_by_type_name("HIV first visit").first.observations.find_by_concept_name("Location of first positive HIV test").first
   end	   
    yes_concept = Concept.find_by_name("Yes")
    #tranfer in patient
    if hiv_first_visit.observations.find_last_by_concept_name("Ever received ART").answer_concept == yes_concept and hiv_first_visit.observations.find_last_by_concept_name("Ever registered at ART clinic").answer_concept == yes_concept
    return self.encounters.find_by_type_name("HIV first visit").first.observations.find_by_concept_name("Site transfered from").first
   end	    
  end

  def first_cd4_count
   Observation.find(:first,:conditions => ["concept_id=? and patient_id=?",(Concept.find_by_name("CD4 Count").id),self.patient_id],:order=>"obs.obs_datetime asc")
 end

  def first_cd4_count_date
   Observation.find(:first,:conditions => ["concept_id=? and patient_id=?",(Concept.find_by_name("CD4 test date").id),self.patient_id],:order=>"obs.obs_datetime asc")
 end

  def hl7_arv_number
    begin
      self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("Arv national id").id) 
    rescue
     return nil
   end
  end

  def date_of_starting_first_line_alt
    begin
      return  self.observations.find_by_concept_name("ARV First line regimen alternatives")
    rescue
      return nil
    end	    
  end	  
#End of HL 7 functions


  def valid_visit?(date = Date.today)
    encounters_types_for_day = self.encounters.find_by_date(date).collect{|encounter|encounter.name}
    expected_encounter_types = ["ART Visit", "Give drugs", "HIV Reception", "Height/Weight"]

    if encounters_types_for_day.include?("Give drugs") and not (["ART Visit", "HIV Reception"] - encounters_types_for_day).empty?
      print self.national_id.to_s + " " +self.name + " " 
      puts encounters_types_for_day.join(", ")
      return false
    end

    return true
  end
  
  def last_art_visit_date(date = Date.today) 
   date = date.to_s.to_time
   encounter_types_id = EncounterType.find_by_name("ART Visit").id
   return Encounter.find(:first,
          :conditions=>["patient_id=? and encounter_type=? and encounter_datetime < ?",
          self.id,encounter_types_id,date],:order=> "encounter_datetime desc").encounter_datetime rescue nil
  end

  def needs_cd4_count?(date = Date.today)
   last_visit_date = self.last_art_visit_date(date)
   date_when_started_art = self.date_started_art
   return false if date_when_started_art.blank?
   return false if last_visit_date.blank?
   return false if date_when_started_art > date.to_time
   duration = GlobalProperty.find_by_property("months_to_remind_cd4_count").property_value.to_i rescue 6
   last_reminder_date = date_when_started_art

   last_cd4_by_patient = LabSample.last_cd4_by_patient(self.id_identifiers)
   unless last_cd4_by_patient.blank?
     last_cd4_date = last_cd4_by_patient.DATE.to_time
     return false if (date.to_time < last_cd4_date)
     return (((date.to_time - last_cd4_date)/1.month).floor).months >= duration.months
   end

   while last_reminder_date < date.to_time
    last_reminder_date = (last_reminder_date+= duration.months)
   end
   last_reminder_date = (last_reminder_date - duration.months)
   date_boundary_lowest =  last_reminder_date - 10.day
   return last_visit_date < date_boundary_lowest
  end

  def self.empty_cohort_data_hash
    cohort_values = Hash.new(0)
    cohort_values["regimen_types"] = Hash.new
    cohort_values["occupations"] = Hash.new
    cohort_values["start_reasons"] = Hash.new
    cohort_values["outcome_statuses"] = Hash.new    
    cohort_values["messages"] = Array.new
    return cohort_values
  end

  def valid_for_cohort?(start_date, end_date)
    return false if self.voided?
    date_started_art = self.date_started_art
    return false if date_started_art.blank?
    return false unless self.date_started_art.to_date.between?(start_date, end_date)
    return true
  end

  def cohort_data(start_date, end_date, cohort_values=nil)
    @quarter_start = start_date
    @quarter_end = end_date

    if cohort_values.nil?
#      cohort_values = Patient.empty_cohort_data_hash
    end

    Report.cohort_patient_ids[:all] << self.id

    patient_started_as_adult = true

    cohort_values["all_patients"] += 1 
      if self.gender == "Male"
        cohort_values["male_patients"] += 1
      else
        cohort_values["female_patients"] += 1
      end
      if self.child_at_initiation?
        cohort_values["child_patients"] += 1
        patient_started_as_adult = false
      else
        cohort_values["adult_patients"] += 1
      end
      
      #njero qech debug
      #f = this_patient.observations.find_by_concept_name("Date of ART initiation").first
      #@art_inits ||= ""
      #@art_inits += "\n#{this_patient.id}/#{f.value_datetime if f}"

      patient_occupation = self.occupation
      patient_occupation ||= "Other" 
      #patient_occupation = patient_occupation.capitalize
      patient_occupation = patient_occupation.downcase
      patient_occupation = 'soldier/police' if patient_occupation =~ /police|soldier/
      if cohort_values["occupations"].has_key?(patient_occupation) then
        cohort_values["occupations"][patient_occupation] += 1
        Report.cohort_patient_ids[:occupations][patient_occupation] << self.id
      else
        cohort_values["occupations"][patient_occupation] = 1
        Report.cohort_patient_ids[:occupations][patient_occupation] = [self.id]
      end

      reason_for_art_eligibility = self.reason_for_art_eligibility
      start_reason = reason_for_art_eligibility ? reason_for_art_eligibility.name : "Unknown"
      start_reason = 'WHO Stage 4' if start_reason == 'WHO stage 4 adult' or start_reason == 'WHO stage 4 peds'
      start_reason = 'WHO Stage 3' if start_reason == 'WHO stage 3 adult' or start_reason == 'WHO stage 3 peds'
      if cohort_values["start_reasons"].has_key?(start_reason) then
        cohort_values["start_reasons"][start_reason] += 1
        Report.cohort_patient_ids[:start_reasons][start_reason] << self.id
      else
        cohort_values["start_reasons"][start_reason] = 1
        Report.cohort_patient_ids[:start_reasons][start_reason] = [self.id]
      end

      cohort_visit_data = self.get_cohort_visit_data(@quarter_start, @quarter_end)                      
      if cohort_visit_data["Extrapulmonary tuberculosis"] == true
        cohort_values["start_cause_EPTB"] += 1
        Report.cohort_patient_ids[:start_reasons]['start_cause_EPTB'] ||= []
        Report.cohort_patient_ids[:start_reasons]['start_cause_EPTB'] << self.id
      elsif cohort_visit_data["Pulmonary tuberculosis within the last 2 years"] == true
        cohort_values["start_cause_PTB"] += 1
        Report.cohort_patient_ids[:start_reasons]['start_cause_PTB'] ||= []
        Report.cohort_patient_ids[:start_reasons]['start_cause_PTB'] << self.id
      elsif cohort_visit_data["Pulmonary tuberculosis (current)"] == true 
        cohort_values["start_cause_APTB"] += 1
        Report.cohort_patient_ids[:start_reasons]['start_cause_APTB'] ||= []
        Report.cohort_patient_ids[:start_reasons]['start_cause_APTB'] << self.id
      end
      if cohort_visit_data["Kaposi's sarcoma"] == true
        cohort_values["start_cause_KS"] += 1
        Report.cohort_patient_ids[:start_reasons]['start_cause_KS'] ||= []
        Report.cohort_patient_ids[:start_reasons]['start_cause_KS'] << self.id
      end
      pmtct_obs = self.observations.find_by_concept_name("Referred by PMTCT").last
      if pmtct_obs and pmtct_obs.value_coded == 3
        cohort_values["pmtct_pregnant_women_on_art"] +=1
        Report.cohort_patient_ids[:start_reasons]['pmtct_pregnant_women_on_art'] ||= []
        Report.cohort_patient_ids[:start_reasons]['pmtct_pregnant_women_on_art'] << self.id
      end
      
      outcome_status = self.cohort_outcome_status(@quarter_start, @quarter_end)
=begin
      if cohort_values["outcome_statuses"].has_key?(outcome_status) then
        cohort_values["outcome_statuses"][outcome_status] += 1
      else
        cohort_values["outcome_statuses"][outcome_status] = 1
      end
=end
			last_visit_datetime = cohort_visit_data["last_encounter_datetime"]
      
      if outcome_status == "Died" 
        cohort_values["dead_patients"] += 1
        Report.cohort_patient_ids[:outcome_data]['died'] ||= []
        Report.cohort_patient_ids[:outcome_data]['died'] << self.id
        unless self.death_date.blank?
          art_start_date = self.date_started_art
          death_date = self.death_date
          mins_to_months = 60*60*24*7*4 # get 4 week months from minutes
          months_of_treatment = 0
          months_of_treatment = ((death_date.to_time - art_start_date.to_time)/mins_to_months).ceil unless art_start_date.nil?
          if months_of_treatment <= 1  
            cohort_values["died_1st_month"] += 1 
            Report.cohort_patient_ids[:of_those_who_died]['month1'] ||= []
            Report.cohort_patient_ids[:of_those_who_died]['month1'] << self.id
          elsif months_of_treatment == 2  
            cohort_values["died_2nd_month"] += 1
            Report.cohort_patient_ids[:of_those_who_died]['month2'] ||= []
            Report.cohort_patient_ids[:of_those_who_died]['month2'] << self.id
          elsif months_of_treatment == 3  
            cohort_values["died_3rd_month"] += 1
            Report.cohort_patient_ids[:of_those_who_died]['month3'] ||= []
            Report.cohort_patient_ids[:of_those_who_died]['month3'] << self.id
          elsif months_of_treatment > 3 
            cohort_values["died_after_3rd_month"] += 1
            Report.cohort_patient_ids[:of_those_who_died]['after_month3'] ||= []
            Report.cohort_patient_ids[:of_those_who_died]['after_month3'] << self.id
          end
        else
          cohort_values["messages"].push "Patient id #{self.id} has the outcome status 'Died' but no death date is set"  
        end  
      elsif outcome_status.include? "Transfer Out"
        cohort_values["transferred_out_patients"] += 1 
        Report.cohort_patient_ids[:outcome_data]['transferred_out'] ||= []
        Report.cohort_patient_ids[:outcome_data]['transferred_out'] << self.id
      elsif outcome_status == "ART Stop" 
        cohort_values["art_stopped_patients"] += 1  
        Report.cohort_patient_ids[:outcome_data]['stopped'] ||= []
        Report.cohort_patient_ids[:outcome_data]['stopped'] << self.id
      elsif last_visit_datetime.nil? or (@quarter_end - last_visit_datetime.to_date).to_i > 90  
        cohort_values["defaulters"] += 1 
        Report.cohort_patient_ids[:outcome_data]['defaulted'] ||= []
        Report.cohort_patient_ids[:outcome_data]['defaulted'] << self.id
      elsif outcome_status == "Alive and on ART" || outcome_status == "On ART"
        cohort_values["alive_on_ART_patients"] += 1 
        Report.cohort_patient_ids[:outcome_data]['on_art'] ||= []
        Report.cohort_patient_ids[:outcome_data]['on_art'] << self.id
        regimen_type = self.cohort_last_art_regimen(@quarter_start, @quarter_end)
        if (regimen_type)
          cohort_values["regimen_types"][regimen_type] ||= 0
          cohort_values["regimen_types"][regimen_type] += 1
          Report.cohort_patient_ids[:outcome_data][regimen_type] ||= []
          Report.cohort_patient_ids[:outcome_data][regimen_type] << self.id
          if cohort_visit_data["Is able to walk unaided"] == true
            cohort_values["ambulatory_patients"] += 1
            Report.cohort_patient_ids[:of_those_on_art]['ambulatory'] ||= []
            Report.cohort_patient_ids[:of_those_on_art]['ambulatory'] << self.id
          end
          if cohort_visit_data["Is at work/school"] == true
            cohort_values["working_patients"] += 1
            Report.cohort_patient_ids[:of_those_on_art]['working'] ||= []
            Report.cohort_patient_ids[:of_those_on_art]['working'] << self.id
          end

          if patient_started_as_adult and regimen_type == "ARV First line regimen" and not cohort_visit_data["Pill count"].nil?
            cohort_values["on_1st_line_with_pill_count_adults"] += 1 
            Report.cohort_patient_ids[:outcome_data]['on_1st_line_with_pill_count_adults'] ||= []
            Report.cohort_patient_ids[:outcome_data]['on_1st_line_with_pill_count_adults'] << self.id
            if cohort_visit_data["Pill count"] <= 8
              cohort_values["adherent_patients"] += 1
              Report.cohort_patient_ids[:outcome_data]['adherent'] ||= []
              Report.cohort_patient_ids[:outcome_data]['adherent'] << self.id
            end
          end
        else
          cohort_values['regimen_types']['Unknown'] ||= 0
          cohort_values['regimen_types']['Unknown'] += 1
        end            

        # Side effects
        side_effect_found = false
        if cohort_visit_data["Peripheral neuropathy"] or cohort_visit_data['Leg pain / numbness']
          cohort_values["peripheral_neuropathy_patients"] += 1
          side_effect_found = true
        end
        if cohort_visit_data["Hepatitis"] or cohort_visit_data["Jaundice"]
          cohort_values["hepatitis_patients"] += 1
          side_effect_found = true
        end
        if cohort_visit_data["Skin rash"]
          cohort_values["skin_rash_patients"] += 1
          side_effect_found = true
        end
        if cohort_visit_data["Lactic acidosis"]
          cohort_values["lactic_acidosis_patients"] += 1
          side_effect_found = true
        end
        if cohort_visit_data["Lipodystrophy"]
          cohort_values["lipodystropy_patients"] += 1 if cohort_visit_data["Lipodystrophy"]
          side_effect_found = true
        end
        if cohort_visit_data["Anaemia"]
          cohort_values["anaemia_patients"] += 1 if cohort_visit_data["Anaemia"]
          side_effect_found = true
        end
        if cohort_visit_data["Other side effect"] or cohort_visit_data['Other symptom']
          cohort_values["other_side_effect_patients"] += 1
          side_effect_found = true
        end
        if side_effect_found
          Report.cohort_patient_ids[:of_those_on_art]['side_effects'] ||= []
          Report.cohort_patient_ids[:of_those_on_art]['side_effects'] << self.id
        end
      end
      return cohort_values

  end

  def destroy_patient 
   self.encounters.each{|en|en.observations.each{|ob|ob.destroy}}
   self.encounters.each{|en|en.destroy}
   unless self.people.blank?
    self.people.each{|person|person.destroy}
   end	   
   
   unless self.observations.blank?
    self.observations.each{|person|person.destroy}
   end	   
   unless self.patient_programs.blank?
    self.patient_programs.each{|p|p.destroy}
   end	   
   self.destroy
  end
 
  # TODO: DRY!!!
  # This method should return self.encounters.last or vicerversa
  def last_encounter_by_patient
   return Encounter.find(:first, :conditions =>["patient_id = ?",self.id],:order =>"encounter_datetime desc") rescue nil
  end

  def active_patient?
	 months = 18.months
   patient_last_encounter_date = self.last_encounter_by_patient.encounter_datetime rescue nil
   return true if patient_last_encounter_date.blank?

   if (Time.now - (patient_last_encounter_date) >= months)
     return false
   else
     return true   
   end
  end

  def id_identifiers
    identifier_type = "Legacy pediatric id","National id","Legacy national id","New national id"
    identifier_types = PatientIdentifierType.find(:all,:conditions=>["name IN (?)",identifier_type]).collect{|id|id.patient_identifier_type_id} rescue nil
    return PatientIdentifier.find(:all,:conditions=>["voided = 0 AND patient_id=? AND identifier_type IN (?)",self.id,identifier_types]).collect{|identifiers|identifiers.identifier} rescue nil
  end
  
  def detail_lab_results(test_name=nil)
    test_type = LabPanel.get_test_type(test_name)
    return if test_type.blank?
    patient_ids = self.id_identifiers 
    return LabSample.lab_trail(patient_ids,test_type)
  end
  
  def available_lab_results
    patient_ids = self.id_identifiers 
    test_table_accession_num = LabTestTable.find(:all,:conditions =>["Pat_ID IN (?)",patient_ids],:group =>"AccessionNum").collect{|num|num.AccessionNum.to_i} rescue []
    sample_table_accession_num = LabSample.find(:all,:conditions =>["PATIENTID IN (?)",patient_ids],:group =>"AccessionNum").collect{|num|num.AccessionNum.to_i} rescue []
    available_accession_num = (test_table_accession_num + sample_table_accession_num).uniq 
    return if available_accession_num.blank?  

    all_patient_samples = LabSample.find(:all,:conditions=>["AccessionNum IN (?)",available_accession_num],:group=>"Sample_ID").collect{|sample|sample.Sample_ID} rescue nil
    available_test_types = LabParameter.find(:all,:conditions=>["Sample_Id IN (?)",all_patient_samples],:group=>"TESTTYPE").collect{|types|types.TESTTYPE} rescue nil
    available_test_types = LabTestType.find(:all,:conditions=>["TestType IN (?)",available_test_types]).collect{|n|n.Panel_ID} rescue nil
    return if available_test_types.blank?
    return LabPanel.test_name(available_test_types) 
  end
  
  def detailed_lab_results_to_display(available_results = Hash.new())
   return if available_results.blank?
   lab_results_to_display = Hash.new()
   available_results.each do |date,lab_result |
    test_date = date.to_s.to_date.strftime("%d-%b-%Y")
    lab_results = lab_result.flatten
    lab_results.each{|result|
      name = LabTestType.test_name(result.TESTTYPE)
      test_value = result.TESTVALUE
      if not result.Range.blank? and not result.Range.strip == '='
        test_result = result.Range + " " + test_value.to_s
      end
     
      test_result = test_value if test_result.blank?
      lab_results_to_display[name] << ":" + test_date.to_s + ":" + test_result.to_s unless lab_results_to_display[name].blank?
      lab_results_to_display[name] = test_date.to_s + ":" + test_result.to_s if lab_results_to_display[name].blank?
    }
   end
   return lab_results_to_display
  end
  
  def available_test_dates(detail_lab_results,return_dates_only=false)
    available_dates = Array.new()
    date_th =nil
    html_tag = Array.new()
    html_tag_to_display = nil
    detail_lab_results.each do |name,lab_result |
      results = lab_result.split(":").enum_slice(2).map
      results.each{|result|
        available_dates << result.first if !available_dates.blank? and !available_dates.include?(result.first) rescue nil
        available_dates << result.first  if available_dates.blank?
      }
    end 
   
    return available_dates.reject{|result|result.blank?}.uniq.sort{|a,b| a.to_date<=>b.to_date} if return_dates_only == true

    available_dates.reject{|result|result.blank?}.uniq.sort{|a,b| a.to_date<=>b.to_date}.each{|date|
      dates = date.to_s
      dates = "Unknown" if date.to_s == "01-Jan-1900"
      date_th+= "<th>#{dates}</th>" unless date_th.blank? rescue nil
      date_th = "<th>&nbsp;</th>" + "<th>#{dates}</th>" if date_th.blank? rescue nil
    }
    return date_th
  end

  def detail_lab_results_html(detail_lab_results)
    available_dates = self.available_test_dates(detail_lab_results,true) 
    patient_name = self.name

    html_tag_to_display = ""
    
    detail_lab_results.sort.each do |name,lab_result |
      test_name = name.gsub("_"," ")
      results = lab_result.split(":").enum_slice(2).map
      results.delete_if{|x|x[0]=="01-Jan-1900"}
      results_to_be_passed_string = ""
      results.each{|y|y.each{|x| if !results_to_be_passed_string.blank? then results_to_be_passed_string+=":" + x else results_to_be_passed_string+=x end}} 
      results_to_be_passed_string = lab_result if results_to_be_passed_string.blank?
      results = lab_result.split(":").enum_slice(2).map  
      test_value = nil
      html_tag = Array.new()
      available_dates.each{|d| 
        html_tag << "<td>&nbsp;</td>" 
      }

      modifier = ""
      results.each{|result|
        date_index = available_dates.index(result.first.to_s) 
        test_value = result.last.to_s
        modifier = test_value.split(" ")[0]
        html_tag[date_index] = "<td>#{test_value}</td>" 
      }
      results_to_be_passed_string = results_to_be_passed_string.sub('=','').sub('<','').sub('>','') + ":" + modifier
      html_tag[0] = "<td class='test_name_td'><input class='test_name' type=\"button\" onmousedown=\"document.location='/patient/detail_lab_results_graph?id=#{results_to_be_passed_string}&name=#{name}&pat_name=#{patient_name}';\" value=\"#{test_name}\"/></td>" + html_tag[0]
      html_tag_to_display+= "<tr>#{html_tag.to_s}</tr>" unless  html_tag[0].blank?
    end
    return html_tag_to_display
  end

  def last_art_visit_ecounter_by_given_date(visit_date)
    date = visit_date.to_s.to_time
    encounter_types_id = EncounterType.find_by_name("ART Visit").id
    Encounter.find(:first,
      :conditions=>["patient_id=? and encounter_type=? and encounter_datetime < ?",
      self.id,encounter_types_id,date],:order=> "encounter_datetime desc") rescue nil
  end

  def drugs_given_last_time(date=Date.today)
    pills_given=self.drug_orders_for_date(date)
    drug_name_and_total_quantity = Hash.new(0)
    pills_given.collect{|dor|
      next unless dor.drug.arv?
      drug_name_and_total_quantity[dor.drug]+= dor.quantity
    }.compact

    drug_name_and_total_quantity
  end

  def adherence_expected_amount_remaining(drug, visit_date, drug_order = [])
    return if drug.blank?
    previous_visit_date = self.last_art_visit_ecounter_by_given_date(visit_date).encounter_datetime.to_s.to_date rescue nil
    return if previous_visit_date.nil?
    drugs_dispensed_last_time = self.drugs_given_last_time(previous_visit_date)
    
    return "Drug not given that visit" unless drugs_dispensed_last_time[drug]
    days_gone = (visit_date - previous_visit_date).to_i
    drug_daily_consumption = drug_order.daily_consumption
    return if drug_daily_consumption.blank?
     
    drugs_dispensed_last_time[drug] - (days_gone * drug_daily_consumption)  
  end

  def expected_amount_remaining(drug,visit_date=Date.today)
    return if drug.blank?
    previous_visit_date = self.last_art_visit_ecounter_by_given_date(visit_date).encounter_datetime.to_s.to_date rescue nil
    return if previous_visit_date.nil?
    drugs_dispensed_last_time = self.drugs_given_last_time(previous_visit_date)

    return "Drug not given that visit" unless drugs_dispensed_last_time[drug]
    
    if self.previous_art_drug_orders(visit_date).blank?
      self.art_amount_remaining_if_adherent(visit_date)[drug] rescue nil
    else  
      self.art_amount_remaining_if_adherent(visit_date,false,previous_visit_date)[drug] rescue nil
    end  
  end

  def doses_unaccounted_for_and_doses_missed(drug_obj,date=Date.today)
    concept_name = "Whole tablets remaining and brought to clinic"
    total_amount = Observation.find(:all,:conditions => ["voided = 0 and concept_id=? and patient_id=? and Date(obs_datetime)=?",(Concept.find_by_name(concept_name).id),self.id,date],:order=>"obs.obs_datetime desc") rescue nil 
    drug_actual_amount_remaining = 0
    total_amount.map{|x|x
      next if x.value_drug != drug_obj.id
      drug_actual_amount_remaining+=x.value_numeric
    }
   
    expected_amount = self.expected_amount_remaining(drug_obj,date)
    result = (expected_amount - drug_actual_amount_remaining)
    result.to_s.match(/-/) ?  "Doses unaccounted for:#{result.to_s.gsub("-","")}" : "Doses missed:#{result}"
  end

  def height_for_age(date=Date.today)
    median_height = WeightHeightForAge.median_height(self)
    height = (self.current_height(date)/(median_height)*100).round rescue nil
  end

  def weight_for_age(date=Date.today)
    median_weight = WeightHeightForAge.median_weight(self) 
    weight = ((self.current_weight(date)/median_weight)*100).round rescue nil
  end

  def weight_for_height(date=Date.today)
    height = WeightForHeight.significant(self.current_height(date))
    median_weight_height = WeightForHeight.patient_weight_for_height_values[height.to_f]
    return nil if median_weight_height.blank?
    weight_for_height = ((self.current_weight(date)/median_weight_height)*100).round
  end
	 
  # Assign ARV numbers to patients in the specified CSV file
  # e.g.: Patient.assign_arv_numbers("/var/www/bart/salima_without_arv_numbers.csv")
  def self.assign_arv_numbers(file_path)
    require "fastercsv"
    pat_id_and_arv_numbers = FasterCSV.read(file_path)
    User.current_user = User.find(64)
    pat_id_and_arv_numbers.each{|row|
      pat = Patient.find(row[0].to_i)
      pat.arv_number = row[1]
      pat.save!
      puts "created #{pat.arv_number}"
    }   
  end 


  # re-cache patients outcomes
  def reset_outcomes
ActiveRecord::Base.connection.execute <<EOF
DELETE FROM patient_historical_outcomes WHERE patient_id = #{self.id};
EOF

ActiveRecord::Base.connection.execute <<EOF
INSERT INTO patient_historical_outcomes (patient_id, outcome_date, outcome_concept_id)
  SELECT encounter.patient_id, encounter.encounter_datetime, 324
  FROM encounter
  INNER JOIN orders ON orders.encounter_id = encounter.encounter_id AND orders.voided = 0
  INNER JOIN drug_order ON drug_order.order_id = orders.order_id 
  INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
  INNER JOIN concept_set as arv_drug_concepts ON
    arv_drug_concepts.concept_set = 460 AND
    arv_drug_concepts.concept_id = drug.concept_id
  WHERE encounter.patient_id = #{self.id}
  UNION
  SELECT obs.patient_id, obs.obs_datetime, obs.value_coded 
  FROM obs  
  WHERE obs.concept_id = 28 AND obs.value_coded <> 373 AND obs.patient_id = #{self.id} AND obs.voided = 0
  UNION
  SELECT obs.patient_id, obs.obs_datetime, 325 
  FROM obs 
  WHERE obs.concept_id = 372 AND obs.value_coded <> 3 AND obs.patient_id = #{self.id} AND obs.voided = 0
  UNION
  SELECT obs.patient_id, obs.obs_datetime, 386 
  FROM obs 
  WHERE obs.concept_id = 367 AND obs.value_coded <> 3 AND obs.patient_id = #{self.id} AND obs.voided = 0
  UNION
  SELECT patient_default_dates.patient_id, patient_default_dates.default_date, 373
  FROM patient_default_dates 
  WHERE patient_default_dates.patient_id = #{self.id}
    AND patient_default_dates.default_date < CURRENT_DATE()
  UNION
  SELECT patient.patient_id, patient.death_date, 322
  FROM patient
  WHERE patient.death_date IS NOT NULL AND patient.patient_id = #{self.id};
EOF

    # Update old Stop Concepts to ART Stop
ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_historical_outcomes
  SET outcome_concept_id = 386
  WHERE patient_id = #{self.id} AND outcome_concept_id = 323;
EOF

  end

  def reset_regimens
    ActiveRecord::Base.connection.execute <<EOF
    DELETE FROM patient_historical_regimens WHERE patient_id = #{self.id};
EOF

    encounter_type = EncounterType.find_by_name('Give drugs').id
    visit_encounter_dates = Patient.find_by_sql("SELECT * FROM encounter e                                        
      INNER JOIN orders o ON o.encounter_id = e.encounter_id AND o.voided = 0
      WHERE (e.patient_id = #{self.id}) AND encounter_type = #{encounter_type}
      GROUP BY DATE(encounter_datetime) ORDER BY encounter_datetime DESC").map(&:encounter_datetime) 


    ActiveRecord::Base.connection.execute <<EOF
     INSERT INTO patient_historical_regimens(regimen_concept_id, patient_id, encounter_id, dispensed_date)  
     SELECT patient_regimen_ingredients.regimen_concept_id as regiment_concept_id,
         patient_regimen_ingredients.patient_id as patient_id,
         patient_regimen_ingredients.encounter_id as encounter_id, 
         patient_regimen_ingredients.dispensed_date as dispensed_date
    FROM 
      (SELECT 
          regimen_ingredient.ingredient_id as ingredient_concept_id,
          regimen_ingredient.concept_id as regimen_concept_id,
          encounter.patient_id as patient_id, 
          encounter.encounter_id as encounter_id, 
          encounter.encounter_datetime as dispensed_date
      FROM encounter
          INNER JOIN orders ON orders.encounter_id = encounter.encounter_id
          INNER JOIN drug_order ON drug_order.order_id = orders.order_id
          INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
          INNER JOIN drug_ingredient as dispensed_ingredient ON drug.concept_id = dispensed_ingredient.concept_id
          INNER JOIN drug_ingredient as regimen_ingredient ON regimen_ingredient.ingredient_id = dispensed_ingredient.ingredient_id 
          INNER JOIN concept as regimen_concept ON regimen_ingredient.concept_id = regimen_concept.concept_id 
          WHERE encounter.encounter_type = 3 AND regimen_concept.class_id = 18 AND orders.voided = 0 AND
          encounter.patient_id = #{self.id}
          GROUP BY encounter.encounter_id, regimen_ingredient.concept_id, regimen_ingredient.ingredient_id)

          AS patient_regimen_ingredients

          GROUP BY patient_regimen_ingredients.encounter_id, patient_regimen_ingredients.regimen_concept_id
          HAVING count(*) = (SELECT count(*) FROM drug_ingredient WHERE drug_ingredient.concept_id = patient_regimen_ingredients.regimen_concept_id); 
EOF
    
      (visit_encounter_dates || []).each do |visit_date|
        regimen_category = PatientHistoricalRegimen.get_regimen_dispensed(self.id,visit_date.to_date)
        next if regimen_category.blank?
        visit_datetime = visit_date.to_date.strftime('%Y-%m-%d %H:%M:%S') rescue nil
        next if visit_datetime.blank?
        ActiveRecord::Base.connection.execute <<EOF
          UPDATE patient_historical_regimens SET category = '#{regimen_category}'
          WHERE patient_id = #{self.id} 
          AND dispensed_date = '#{visit_datetime}'; 
EOF

      end
    return nil 
  end

  def reset_registration_date
ActiveRecord::Base.connection.execute <<EOF
    DELETE FROM patient_registration_dates WHERE patient_id = #{self.id};
EOF
ActiveRecord::Base.connection.execute <<EOF
    INSERT INTO patient_registration_dates (patient_id, location_id, registration_date)
      SELECT encounter.patient_id, encounter.location_id, MIN(encounter.encounter_datetime)
      FROM encounter
      INNER JOIN orders ON orders.encounter_id = encounter.encounter_id AND orders.voided = 0
      INNER JOIN drug_order ON drug_order.order_id = orders.order_id
      INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
      INNER JOIN concept_set as arv_drug_concepts ON arv_drug_concepts.concept_set = 460 AND arv_drug_concepts.concept_id = drug.concept_id  
      WHERE encounter.encounter_type = 3 AND encounter.patient_id = #{self.id}
      GROUP BY patient_id
EOF
  end
  
  def reset_start_date
ActiveRecord::Base.connection.execute <<EOF
    DELETE FROM patient_start_dates WHERE patient_id = #{self.id};
EOF

ActiveRecord::Base.connection.execute <<EOF
INSERT INTO patient_start_dates (patient_id, start_date, age_at_initiation)
  SELECT 
    patient_dispensations_and_initiation_dates.patient_id, 
    MIN(start_date) AS start_date, 
    (YEAR(start_date) - YEAR(birthdate)) + IF(((MONTH(start_date) - MONTH(birthdate)) + IF((DAY(start_date) - DAY(birthdate)) < 0, -1, 0)) < 0, -1, 0) +
    (IF((birthdate_estimated = 1 AND MONTH(birthdate) = 7 AND DAY(birthdate) = 1 AND MONTH(start_date) < MONTH(birthdate)), 1, 0)) AS age_at_initiation 
  FROM patient_dispensations_and_initiation_dates
  INNER JOIN patient ON patient.patient_id = patient_dispensations_and_initiation_dates.patient_id
  WHERE patient_dispensations_and_initiation_dates.patient_id = #{self.id}
  GROUP BY patient_dispensations_and_initiation_dates.patient_id;
EOF
  end

  def date_of_positive_hiv_test
    date_of_positive_hiv_test_was_entered = self.observations.find(:last,:conditions => ["(concept_id = ? AND voided = 0)",
                                                                Concept.find_by_name("Date of positive HIV test").id]) != nil
     if date_of_positive_hiv_test_was_entered
       return self.observations.find(:last,:conditions => ["(concept_id = ? and voided = 0)", 
                                     Concept.find_by_name("Date of positive HIV test").id]).value_datetime
     else 
       return self.date_created
     end 
  end

  def phone_numbers
    phone_numbers = {}
    ["Cell phone number","Home phone number","Office phone number"].each{|phone|
      number  = self.get_identifier(phone) 
      phone_numbers[phone] = number 
    }
    phone_numbers 
  end
     
  def mastercard_demographics

     first_line_drugs=nil
     first_line_alt_drugs = nil
     second_line_drugs = nil
     arv_number_bold = false
     pregnant_bold = false

     self.regimen_start_dates.each{|type,details|
       case type
         when "ARV First line regimen"
           first_line_drugs = details.split(':')[1] +  " (#{details.split(':')[0]})"
         when "ARV First line regimen alternatives"
           first_line_alt_drugs = details.split(':')[1] +  " (#{details.split(':')[0]})"
         when "ARV Second line regimen"
           second_line_drugs = details.split(':')[1] +  " (#{details.split(':')[0]})"
       end    
     } rescue nil

     pregnant = "N/A"
     
     if self.sex == "Female"
       encounter_datetime = self.encounters.find_first_by_type_name("HIV First visit").encounter_datetime rescue nil
       if encounter_datetime 
         start_date = encounter_datetime.to_date.to_s + " 00:00:00"
         end_date = encounter_datetime.to_date.to_s + " 23:59:59"
         concept_id = Concept.find_by_name("Pregnant").id rescue nil
  
         pregnant = Observation.find(:first,:conditions => ["(obs_datetime >='#{start_date}' and obs_datetime <='#{end_date}') and concept_id=#{concept_id} and patient_id=#{self.id} and voided=0"],:order => "obs_datetime desc").answer_concept.name rescue "Unknown"
       end
     end
     
     pregnant_bold = true if pregnant == "Yes"

     phone_numbers = self.phone_numbers
     phone_number = phone_numbers["Office phone number"] if phone_numbers["Office phone number"].downcase!= "not available" ||  phone_numbers["Office phone number"].downcase!= "unknown" rescue nil
     phone_number= phone_numbers["Home phone number"] if phone_numbers["Home phone number"].downcase!= "not available" ||  phone_numbers["Home phone number"].downcase!= "unknown" rescue nil
     phone_number = phone_numbers["Cell phone number"] if phone_numbers["Cell phone number"].downcase!= "not available" ||  phone_numbers["Cell phone number"].downcase!= "unknown" rescue nil
     phone_number = phone_numbers["Cell phone number"] if phone_number.blank?
     initial_height = self.initial_height.to_s + ' (cm)' rescue "N/A"
     initial_weight = self.initial_weight.to_s + ' (kg)' rescue "N/A"

     tb_status = self.tb_status(self.date_started_art.to_date) rescue nil
     reason_for_art = self.reason_for_art_eligibility.name rescue "Who stage: #{self.who_stage}"
     if reason_for_art.match(/CD4 count/i)
       reason_for_art = reason_for_art.gsub(/</,'<=')
     end
     arv_number = self.arv_number
     arv_number_bold = true if arv_number
     first_line_alt = false
     second_line =false
     first_line_alt = true if first_line_alt_drugs
     second_line = true  if second_line_drugs

     cd4_count_obs = self.observations.find_by_concept_name("CD4 Count").first rescue nil 
     if cd4_count_obs
       cd4_count = "#{cd4_count_obs.value_modifier.gsub('=','=')} #{cd4_count_obs.value_numeric},".strip rescue nil
       cd4_count_date = "(#{cd4_count_obs.obs_datetime.strftime('%d-%b-%Y')})" rescue nil
     else
       cd4_count = "CD4 count: N/A" and cd4_count_date = ""
     end

     physical_address = self.physical_address.strip rescue "N/A"
     art_guardian_name = "#{self.art_guardian.name rescue 'None'} #{'(' + self.art_guardian_type.name + ')' rescue nil}"
     transfer_in = "Yes #{self.encounters.find_first_by_type_name("HIV First visit").encounter_datetime.strftime('%d-%b-%Y') rescue nil}" if self.transfer_in?

     label = ZebraPrinter::StandardLabel.new
     label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
     label.draw_text("#{arv_number}",575,30,0,3,1,1,arv_number_bold)
     label.draw_text("PATIENT DETAILS",25,30,0,3,1,1,false)
     label.draw_text("Name:  #{self.name} (#{self.sex.first})",25,60,0,3,1,1,false)
     label.draw_text("DOB:   #{self.birthdate_for_printing}",25,90,0,3,1,1,false)
     label.draw_text("Phone: #{phone_number}",25,120,0,3,1,1,false)
     if physical_address.length > 48
       label.draw_text("Addr:  #{physical_address[0..47]}",25,150,0,3,1,1,false)
       label.draw_text("    :  #{physical_address[48..-1]}",25,180,0,3,1,1,false)
       last_line = 180
     else
       label.draw_text("Addr:  #{physical_address}",25,150,0,3,1,1,false)
       last_line = 150
     end  

     if last_line == 180 and art_guardian_name.length < 48
       label.draw_text("Guard: #{art_guardian_name}",25,210,0,3,1,1,false)
       last_line = 210
     elsif last_line == 180 and art_guardian_name.length > 48
       label.draw_text("Guard: #{art_guardian.name[0..47]}",25,210,0,3,1,1,false)
       label.draw_text("     : #{art_guardian.name[48..-1]}",25,240,0,3,1,1,false)
       last_line = 240
     elsif last_line == 150 and art_guardian_name.length > 48
       label.draw_text("Guard: #{art_guardian.name[0..47]}",25,180,0,3,1,1,false)
       label.draw_text("     : #{art_guardian.name[48..-1]}",25,210,0,3,1,1,false)
       last_line = 210
     elsif last_line == 150 and art_guardian_name.length < 48
       label.draw_text("Guard: #{art_guardian_name}",25,180,0,3,1,1,false)
       last_line = 180
     end  
   
     label.draw_text("TI:    #{transfer_in ||= 'No'}",25,last_line+=30,0,3,1,1,false)
     label.draw_text("FUP:   (#{self.requested_observation('Agrees to followup')})",25,last_line+=30,0,3,1,1,false)

      
     label2 = ZebraPrinter::StandardLabel.new
     #Vertical lines
=begin
     label2.draw_line(45,40,5,242)
     label2.draw_line(805,40,5,242)
     label2.draw_line(365,40,5,242)
     label2.draw_line(575,40,5,242)
    
     #horizontal lines
     label2.draw_line(45,40,795,3)
     label2.draw_line(45,80,795,3)
     label2.draw_line(45,120,795,3)
     label2.draw_line(45,200,795,3)
     label2.draw_line(45,240,795,3)
     label2.draw_line(45,280,795,3)
=end
     label2.draw_line(25,170,795,3)
     #label data
     label2.draw_text("STATUS AT ART INITIATION",25,30,0,3,1,1,false)
     label2.draw_text("(DSA:#{self.date_started_art.strftime('%d-%b-%Y') rescue 'N/A'})",370,30,0,2,1,1,false)
     label2.draw_text("#{arv_number}",580,20,0,3,1,1,arv_number_bold)
     label2.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",25,300,0,1,1,1,false)

     label2.draw_text("RFS: #{reason_for_art}",25,70,0,2,1,1,false)
     label2.draw_text("#{cd4_count} #{cd4_count_date}",25,110,0,2,1,1,false)
     label2.draw_text("1st + Test:",25,150,0,2,1,1,false)
 
     label2.draw_text("TB: #{tb_status}",380,70,0,2,1,1,false)
     label2.draw_text("KS:#{self.requested_observation('Kaposi\'s sarcoma')}",380,110,0,2,1,1,false)
     label2.draw_text("Preg:#{pregnant}",380,150,0,2,1,1,pregnant_bold)
     label2.draw_text("#{first_line_drugs[0..32] rescue nil}",25,190,0,2,1,1,false)
     label2.draw_text("#{first_line_alt_drugs[0..32] rescue nil}",25,230,0,2,1,1,first_line_alt)
     label2.draw_text("#{second_line_drugs[0..32] rescue nil}",25,270,0,2,1,1,second_line)

     label2.draw_text("HEIGHT: #{initial_height}",570,70,0,2,1,1,false)
     label2.draw_text("WEIGHT: #{initial_weight}",570,110,0,2,1,1,false)
     label2.draw_text("Init Age: #{self.age_at_initiation}",570,150,0,2,1,1,false)

     line = 190
     extra_lines = []
     label2.draw_text("STAGE DEFINING CONDITIONS",450,190,0,3,1,1,false)
     self.stage_defined_conditions.each{|condition|
      line+=25
      if line <= 290
        label2.draw_text(condition[0..35],450,line,0,1,1,1,false) 
      end
      extra_lines << condition[0..79] if line > 290
     }

     if line > 310 and !extra_lines.blank?
      line = 30 
      label3 = ZebraPrinter::StandardLabel.new
      label3.draw_text("STAGE DEFINING CONDITIONS",25,line,0,3,1,1,false)
      label3.draw_text("#{arv_number}",370,line,0,2,1,1,arv_number_bold)
      label3.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
      extra_lines.each{|condition| 
        label3.draw_text(condition,25,line+=30,0,2,1,1,false)
      }
     end
     return "#{label.print(1)} #{label2.print(1)} #{label3.print(1)}" if !extra_lines.blank?
     return "#{label.print(1)} #{label2.print(1)}"
  end

  def stage_defined_conditions
    stage_defined_conditions = []
    yes = Concept.find_by_name("Yes").id
    encounter_type = EncounterType.find_by_name("HIV Staging").id
    Observation.find(:all,:joins => "INNER JOIN encounter e ON e.encounter_id = obs.encounter_id",
      :conditions => ["e.encounter_type = ? AND e.patient_id = ? AND voided = 0 ",
      encounter_type,self.id]).each{|obs|
        next unless obs.value_coded == yes
        condition = obs.concept.short_name 
        condition = obs.concept.name if condition.blank?
        if condition == "CD4 count available"
          concept_id = Concept.find_by_name("CD4 count available").id
          first_cd4_count = Observation.find(:first,
            :conditions => ["voided = 0 and concept_id = ? AND patient_id=?",
            concept_id,patient_id],:order => "obs_datetime DESC")
          cd4_count_plus_modifier = self.cd4_count(first_cd4_count.obs_datetime).split(" ") rescue nil
          cd4_count = cd4_count_plus_modifier[1] || cd4_count_plus_modifier rescue nil
          cd4_modifier = cd4_count_plus_modifier[0] unless cd4_count_plus_modifier[1].blank? rescue nil
          cd4_modifier = "equal" if cd4_modifier == "="
          cd4_modifier = "more than" if cd4_modifier == ">"
          cd4_modifier = "less than" if cd4_modifier == "<"
          condition = "CD count: #{cd4_modifier} #{cd4_count}" rescue nil
        end  
        stage_defined_conditions << condition
      } 
    stage_defined_conditions    
  end

  def mastercard_visit_label(date = Date.today)
    visit = MastercardVisit.visit(self,date)
    visit_data = mastercard_visit_data(visit)

    se_bold = false 
    tb_bold = false 
    outcome_bold = false 
    adh_bold = false 
    arv_bold = false 
    arv_number_bold = false

    outcome_bold = true if visit_data['outcome'] and !visit_data['outcome'].include?("Next")
    se_bold = true if (visit.s_eff and (visit.s_eff == "PN" || visit.s_eff == "SK" || visit.s_eff=="HP"))
    tb_bold = true if visit.tb_status and visit.tb_status != "None"
    adh_bold = true if (visit.adherence  and (visit.adherence.to_i <= 95 || visit.adherence.to_i >= 105) and visit.adherence != "N/A")
    current_location =  Location.current_location.name
    if current_location == "Lighthouse" || current_location == "Martin Preuss Centre"
      arv_number = self.print_national_id || self.arv_number
      arv_number_bold = true if arv_number
    else
      arv_number = self.arv_number || self.print_national_id
      arv_number_bold = true if arv_number
    end  
	  provider = self.encounters.find_by_type_name_and_date("ART Visit", date)
	  provider = self.encounters.find_by_type_name_and_date("Pre ART Visit", date) if provider.blank?
	  provider_username = "#{'Seen by: ' + provider.last.provider.username}" rescue nil
    if provider_username.blank? and visit_data['outcome'] == "Died"
      provider_id = self.observations.find_last_by_concept_name_on_date("Outcome",date).creator rescue nil
	    provider_username = "#{'Recorded by: ' + User.find(provider_id).username}" rescue nil
    end  

    arv_bold = visit.reg_type != "ARV First line regimen"

    visit_height = "#{visit.height} cm" unless visit.height.blank?
    if visit_height.blank? and not self.child?
      visit_height = "#{self.current_height} cm" unless self.current_height.blank?
    end

    label = ZebraPrinter::StandardLabel.new
    label.number_of_labels = 2
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{provider_username}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    label.draw_text("#{arv_number}",565,30,0,3,1,1,arv_number_bold)
    label.draw_text("#{self.name}(#{self.sex.first})",25,60,0,3,1,1,false)
    label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit_height} #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?} #{'(PC:' + visit.pills[0..24] + ')' unless visit.pills.blank?}",25,95,0,2,1,1,false)
    label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    label.draw_text("Adh",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,tb_bold)
    label.draw_text("#{visit.adherence.gsub('%', '\\\\%') rescue nil}",185,160,0,2,1,1,adh_bold)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,outcome_bold)
    label.draw_text("#{visit_data['outcome_date']}",655,160,0,2,1,1,false)
    starting_index = 25
    start_line = 160
    visit_data.each{|key,values|
      data = values.last rescue nil
      next if data.blank?
      bold = false
      bold = true if key.include?("side_eff") and data !="None"
      bold = true if key.include?("arv_given") and arv_bold
      starting_index = values.first.to_i
      starting_line = start_line 
      starting_line = start_line + 30 if key.include?("2")
      starting_line = start_line + 60 if key.include?("3")
      starting_line = start_line + 90 if key.include?("4")
      starting_line = start_line + 120 if key.include?("5")
      starting_line = start_line + 150 if key.include?("6")
      starting_line = start_line + 180 if key.include?("7")
      starting_line = start_line + 210 if key.include?("8")
      starting_line = start_line + 240 if key.include?("9")
      next if starting_index == 0
      label.draw_text("#{data}",starting_index,starting_line,0,2,1,1,bold)
    }
    label.print(1)
  end

   def mastercard_visit_data(visit)
    return if visit.blank?
    data = {}
    
    data["outcome"] = visit.outcome
    data["outcome"] = "Next: #{visit.next_app.strftime('%b %d %Y')}" if visit.next_app and (data["outcome"] == "Alve" || data["outcome"].blank?)
    data["outcome_date"] = "#{visit.date_of_outcome.to_date.strftime('%b %d %Y')}" if visit.date_of_outcome

    count = 1
    visit.s_eff.split(",").each{|side_eff|
      data["side_eff#{count}"] = "25",side_eff[0..5]
      count+=1
    } if visit.s_eff

    count = 1
    visit.reg.each{|pills_gave|
      data["arv_given#{count}"] = "255",pills_gave[0..26] 
      count+= 1
    } if visit.reg
    unless visit.cpt.blank?
      data["arv_given#{count}"] = "255","CPT (#{visit.cpt})" unless visit.cpt == 0
    end
    unless visit.ipt.blank?
      data["arv_given#{count}"] = "255","IPT (#{visit.ipt})" unless visit.ipt == 0
    end
=begin
    count = 2 
    visit.pills.split(',').each{|pills|
      data["pills_remaining#{count}"] = "255",pills[0..26] 
      count+= 1
    } if visit.pills
    data["pills_remaining#{count}"] = "255","Pills remaining"
=end
    data
  end

  def tb_status(date = Date.today)
	    requested_observation = self.observations.find_last_by_concept_name_on_date("TB status",date)
	    return "None" if requested_observation.blank?
	    requested_observation=requested_observation.result_to_string
	    requested_observation
  end

  def regimen_start_dates
    patient_regimems = PatientHistoricalRegimen.find_by_sql("select * from (select * from patient_historical_regimens where patient_id=#{self.id} order by dispensed_date) as regimen group by regimen_concept_id")

    start_dates = {}
    patient_regimems.each{|regimen|
      regimen_name = regimen.concept.concept_sets.first.name
      dispensed_drugs = "" 
      regimen.encounter.drug_orders.collect{|order|dispensed_drugs+= order.drug.short_name.strip + ", " unless order.drug.name =="Cotrimoxazole 480"}.uniq.compact
      start_dates[regimen_name] = "#{regimen.encounter.encounter_datetime.to_date.to_s}:#{dispensed_drugs.strip[0..-2]}"
    }

    start_dates
  end

  def prepare_for_adherence_reset
    self.reset_daily_consumptions                                               
    self.reset_whole_tablets_remaining_and_brought                              
                                                                                
    ActiveRecord::Base.connection.execute <<EOF                                 
DELETE FROM tmp_patient_dispensations_and_prescriptions WHERE patient_id=#{self.id};
EOF
 
                                                                                
    ActiveRecord::Base.connection.execute <<EOF                                 
INSERT INTO tmp_patient_dispensations_and_prescriptions (                       
  SELECT encounter.patient_id,                                                  
           encounter.encounter_id,                                              
           DATE(encounter.encounter_datetime),                                  
           drug.drug_id,                                                        
           SUM(drug_order.quantity) AS total_dispensed,                         
           whole_tablets_remaining_and_brought.total_remaining AS total_remaining,
           patient_prescription_totals.daily_consumption AS daily_consumption   
    FROM encounter                                                              
    INNER JOIN orders ON orders.encounter_id = encounter.encounter_id AND orders.voided = 0
    INNER JOIN drug_order ON drug_order.order_id = orders.order_id              
    INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id              
    INNER JOIN concept_set as arv_drug_concepts ON                              
      arv_drug_concepts.concept_set = 460 AND                                   
      arv_drug_concepts.concept_id = drug.concept_id                            
    LEFT JOIN patient_whole_tablets_remaining_and_brought AS whole_tablets_remaining_and_brought ON
      whole_tablets_remaining_and_brought.patient_id = encounter.patient_id AND 
      whole_tablets_remaining_and_brought.visit_date = DATE(encounter.encounter_datetime) AND
      whole_tablets_remaining_and_brought.drug_id = drug.drug_id                
    LEFT JOIN patient_prescription_totals ON                                    
      patient_prescription_totals.drug_id = drug.drug_id AND                    
      patient_prescription_totals.patient_id = encounter.patient_id AND         
      patient_prescription_totals.prescription_date = DATE(encounter.encounter_datetime)
    WHERE encounter.patient_id = #{self.id}                                     
    GROUP BY encounter.patient_id,encounter.encounter_id,DATE(encounter.encounter_datetime),drug.drug_id
);                                                                              
EOF


    ActiveRecord::Base.connection.execute <<EOF                                 
DELETE FROM patient_adherence_rates WHERE patient_id = #{self.id};              
EOF

  end

  def reset_adherence_rates
    self.reset_daily_consumptions
    self.reset_whole_tablets_remaining_and_brought
    ActiveRecord::Base.connection.execute <<EOF
DELETE FROM tmp_patient_dispensations_and_prescriptions WHERE patient_id=#{self.id};
EOF

    ActiveRecord::Base.connection.execute <<EOF
INSERT INTO tmp_patient_dispensations_and_prescriptions (
  SELECT encounter.patient_id,
           encounter.encounter_id,
           DATE(encounter.encounter_datetime),
           drug.drug_id,
           SUM(drug_order.quantity) AS total_dispensed,
           whole_tablets_remaining_and_brought.total_remaining AS total_remaining,
           patient_prescription_totals.daily_consumption AS daily_consumption
    FROM encounter
    INNER JOIN orders ON orders.encounter_id = encounter.encounter_id AND orders.voided = 0
    INNER JOIN drug_order ON drug_order.order_id = orders.order_id
    INNER JOIN drug ON drug_order.drug_inventory_id = drug.drug_id
    INNER JOIN concept_set as arv_drug_concepts ON
      arv_drug_concepts.concept_set = 460 AND
      arv_drug_concepts.concept_id = drug.concept_id
    LEFT JOIN patient_whole_tablets_remaining_and_brought AS whole_tablets_remaining_and_brought ON
      whole_tablets_remaining_and_brought.patient_id = encounter.patient_id AND
      whole_tablets_remaining_and_brought.visit_date = DATE(encounter.encounter_datetime) AND
      whole_tablets_remaining_and_brought.drug_id = drug.drug_id
    LEFT JOIN patient_prescription_totals ON
      patient_prescription_totals.drug_id = drug.drug_id AND
      patient_prescription_totals.patient_id = encounter.patient_id AND
      patient_prescription_totals.prescription_date = DATE(encounter.encounter_datetime)
    WHERE encounter.patient_id = #{self.id}
    GROUP BY encounter.patient_id,encounter.encounter_id,DATE(encounter.encounter_datetime),drug.drug_id
);
EOF


    ActiveRecord::Base.connection.execute <<EOF
DELETE FROM patient_adherence_rates WHERE patient_id = #{self.id};
EOF
   
    ActiveRecord::Base.connection.execute <<EOF
INSERT INTO patient_adherence_rates (patient_id,visit_date,drug_id,expected_remaining,adherence_rate) 
SELECT 
t1.patient_id,t1.visit_date,t1.drug_id,SUM(t2.total_dispensed) +  IF(t3.registration_date=t1.previous_visit_date,IFNULL(SUM(t2.total_remaining),0),SUM(t2.total_remaining)) - (t2.daily_consumption * DATEDIFF(t1.visit_date, t2.visit_date)) AS expexted_remaining,adherence_calculator(t1.total_remaining,(t2.total_dispensed + t2.total_remaining),t2.daily_consumption,t1.visit_date,t2.visit_date) AS adherence_rate
FROM patient_whole_tablets_remaining_and_brought t1
INNER JOIN tmp_patient_dispensations_and_prescriptions t2 ON t1.patient_id = t2.patient_id 
AND t1.drug_id=t2.drug_id 
AND t1.previous_visit_date=t2.visit_date
INNER JOIN patient_registration_dates t3 ON t3.patient_id=t1.patient_id
WHERE t1.patient_id=#{self.id}
GROUP BY t1.patient_id, t1.visit_date, t1.drug_id
EOF

  end

  def reset_daily_consumptions
    ActiveRecord::Base.connection.execute <<EOF
DELETE FROM patient_prescription_totals WHERE patient_id=#{self.id};
EOF

    ActiveRecord::Base.connection.execute <<EOF
INSERT INTO patient_prescription_totals (patient_id, drug_id, prescription_date, daily_consumption)
SELECT patient_id, drug_id, DATE(prescription_datetime) as prescription_date, SUM(daily_consumption) AS     daily_consumption 
FROM patient_prescriptions WHERE patient_id=#{self.id}
GROUP BY patient_id, drug_id, prescription_date;  
EOF
  end
 
  def reset_whole_tablets_remaining_and_brought
    ActiveRecord::Base.connection.execute <<EOF
DELETE FROM patient_whole_tablets_remaining_and_brought WHERE patient_id=#{self.id};
EOF

    ActiveRecord::Base.connection.execute <<EOF
INSERT INTO patient_whole_tablets_remaining_and_brought (patient_id, drug_id, visit_date, total_remaining,previous_visit_date)
SELECT patient_id, value_drug, DATE(obs_datetime) as visit_date, value_numeric,
(SELECT t2.visit_date FROM tmp_patient_dispensations_and_prescriptions t2
WHERE t2.patient_id = #{self.id} AND obs.value_drug = t2.drug_id AND t2.visit_date < Date(obs.obs_datetime)
order by t2.visit_date desc LIMIT 1
) AS previous_visit_date
FROM obs
WHERE obs.concept_id = 363 AND obs.voided = 0 AND obs.patient_id=#{self.id}
GROUP BY patient_id, value_drug, visit_date
ORDER BY obs_id DESC;
EOF
  end

  def adherence(given_date = Date.today)
    return "N/A" if given_date.to_date == self.date_started_art.to_date rescue nil

    adherence_rates = PatientAdherenceRate.find(:all,:conditions => ["patient_id=? AND visit_date <= ?",self.id,given_date.to_date])
     
    adherence = {}
    
    adherence_rates.each{|adh|
      next if adh.adherence_rate.blank?
      adherence[Drug.find(adh.drug_id).name] = adh.adherence_rate
    }
    
    #For now we will only show the adherence of the drug with the lowest/highest adherence %
    #i.e if a drug adherence is showing 86% and their is another drug with an adherence of 198%,then 
    #we will show the one with 198%.
    #in future we are planning to show all available drug adherences
  
    adherence_to_show = 0
    adherence_over_100 = 0
    adherence_below_100 = 0
    over_100_done = false
    below_100_done = false

    adherence.each{|drug,adh|
      next if adh.blank?
      drug_adherence = adh.to_i
      if drug_adherence <= 100
        adherence_below_100 = adh.to_i if adherence_below_100 == 0
        adherence_below_100 = adh.to_i if drug_adherence <= adherence_below_100
        below_100_done = true
      else  
        adherence_over_100 = adh.to_i if adherence_over_100 == 0
        adherence_over_100 = adh.to_i if drug_adherence >= adherence_over_100
        over_100_done = true
      end 
      
    }   

    return if !over_100_done and !below_100_done
    over_100 = 0
    below_100 = 0
    over_100 = adherence_over_100 - 100 if over_100_done
    below_100 = 100 - adherence_below_100 if below_100_done

    if over_100 >= below_100 and over_100_done
      return "#{100 - (adherence_over_100 - 100)}%"
    else
      return "#{adherence_below_100}%"
    end
  end
   
  def drugs_remaining_and_brought(date) 
    drugs = {}
    start_date = date.to_date.to_s + " 00:00:00"
    end_date = date.to_date.to_s + " 23:59:59"
    drugs_remaining = Observation.find(:all,
         :conditions => ["voided = 0 and concept_id=? and patient_id=? and obs_datetime >='#{start_date}' and obs_datetime <='#{end_date}'",
         (Concept.find_by_name("Whole tablets remaining and brought to clinic").id),self.patient_id],
         :order=>"obs.obs_datetime desc")
    
    drugs_remaining.each{|obs|drugs[obs.drug] = obs.value_numeric}
    drugs
  end

  def drugs_remaining_and_not_brought(date) 
    drugs = {}
    drugs_remaining = PatientWholeTabletsRemainingAndBrought.find(:all,
         :conditions => ["patient_id=? and visit_date=?",self.id,date.to_date],:order=>"obs.obs_datetime desc")
    
    drugs_remaining.each{|count|drugs[Drug.find(count.drug_id)] = count.total_remaining}
    drugs
  end
   
  def change_appointment_date(use_estimated_dates=false,current_date = nil,new_date = nil)
    concept_id = Concept.find_by_name("Appointment date").id

    unless use_estimated_dates
      encounter = Encounter.find(:first,
                  :joins => "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id",
                  :conditions =>["encounter_type =? AND obs.patient_id = ? AND Date(value_datetime) = ?",
                  EncounterType.find_by_name("Give drugs").id,self.id,current_date.to_date])
      start_date = current_date.to_date.strftime("%Y-%m-%d 00:00:00")
      end_date = current_date.to_date.strftime("%Y-%m-%d 23:59:59")
    else
      start_date = (new_date.to_date - 10.day).strftime("%Y-%m-%d 00:00:00")
      end_date = (new_date.to_date + 10.day).strftime("%Y-%m-%d 23:59:59")
      encounter = Encounter.find(:first,
                  :joins => "INNER JOIN obs ON obs.encounter_id = encounter.encounter_id",
                  :conditions =>["encounter_type =? AND obs.patient_id = ? 
                  AND value_datetime >= ? AND value_datetime <= ?",
                  EncounterType.find_by_name("Give drugs").id,self.id,start_date,end_date],
                  :order => "encounter_datetime DESC")
    end  

    obs = Observation.find(:all,:conditions =>["voided=0 and value_datetime >='#{start_date}' and value_datetime <='#{end_date}' and patient_id = #{self.id} and concept_id=#{concept_id}"])

    obs.each{|ob|
      ob.voided = 1
      ob.voided_by = User.current_user.id
      ob.date_voided = Time.now()
      ob.void_reason = "assign new appointment date"
      ob.save
    } 

    new_appointment_date = Observation.new
    new_appointment_date.encounter_id = encounter.id
    new_appointment_date.patient_id = self.id
    new_appointment_date.concept_id = concept_id
    new_appointment_date.value_datetime = new_date.to_date
    new_appointment_date.obs_datetime = Time.now()
    new_appointment_date.save

  end

  def cd4_count(date = Date.today)
    date = date.to_date
    show_cd4_trail = GlobalProperty.find_by_property("show_lab_trail").property_value rescue "false"

    concept_ids = Concept.find(:all,:conditions => ["name=? or name=?","CD4 percentage","CD4 count"]).collect{|concept|concept.id} 
    available_cd4_tests = Observation.find(:all,:conditions => ["voided = 0 and concept_id IN (?) and patient_id=? and Date(obs_datetime)=?",concept_ids,self.patient_id,date])
    cd4_results = {}

    if !available_cd4_tests.blank?
      available_cd4_tests.each{|result|
        case result.concept_id
          when concept_ids.first
            cd4_results["CD4 percentage"] = "#{result.value_modifier rescue nil} #{result.value_numeric.to_s + "%" rescue nil}" 
          else
            cd4_results["CD4 count"] = "#{result.value_modifier rescue nil} #{result.value_numeric rescue nil}" 
        end
      } rescue nil 

    elsif available_cd4_tests.blank? and show_cd4_trail == "true"

      test_types = LabTestType.find(:all,:conditions=>["(TestName=? or TestName=?)",
                             "CD4_count","CD4_percent"]).map{|type|type.TestType} rescue [] if show_cd4_trail == "true"
      available_cd4_tests = self.detail_lab_results("CD4")[date.strftime("%d-%b-%Y")] rescue []

      unless available_cd4_tests.blank?
        available_cd4_tests.each{|result|
          case result.TESTTYPE 
            when test_types.first 
              cd4_results["CD4 count"] = "#{result.Range rescue nil} #{result.TESTVALUE rescue nil}" 
            else  
              cd4_results["CD4 percentage"] = "#{result.Range rescue nil} #{result.TESTVALUE.to_s + "%" rescue nil}" 
          end
        } rescue nil 
      end
    end

    return cd4_results["CD4 percentage"] if self.child? and !cd4_results["CD4 percentage"].blank?
    cd4_results["CD4 count"]
  end
  
  def given_arvs_before?
    self.drug_orders.each{|order|
      return true if order.drug.arv?
    }
    false
  end
   def self.find_by_demographics(patient_demographics)
    national_id = patient_demographics["person"]["patient"]["identifiers"]["National id"] rescue nil
    patient = Patient.find_by_national_id(national_id) unless national_id.nil?
    gender = patient.first.gender.first rescue nil
    given_name = patient.first.given_name rescue nil
    family_name = patient.first.family_name rescue nil
    family_name2 = ""
    dob = patient.first.birthdate rescue nil
    birth_year = dob.year rescue nil
    birth_month = dob.month rescue nil
    birth_day = dob.day rescue nil
    city_village = patient.first.current_place_of_residence rescue nil
    birthplace = patient.first.birthplace
    arv_number = patient.first.arv_number rescue nil
    date_changed = patient.first.date_changed rescue nil
    occupation = patient.first.occupation rescue nil
    phone_numbers = patient.first.phone_numbers rescue {}
    state_province = patient.first.get_identifier("Physical address")
    county_district = patient.first.traditional_authority


    results = {}
    result_hash = {}

    result_hash = {
      "gender" => "#{gender}",
      "names" => {"given_name" => "#{given_name}",
                  "family_name" => "#{family_name}",
                  "family_name2" => "#{family_name2}"
                  },
      "birth_year" => birth_year,
      "birth_month" => birth_month,
      "birth_day" => birth_day,
      "addresses" => {"city_village" => "#{city_village}",
                      "address2" => "#{birthplace}",
                      "state_province" => "#{state_province}",
                      "county_district" => "#{county_district}"
                      },
      "attributes" => {"occupation" => "#{occupation}",
                      "home_phone_number" => "#{phone_numbers['Home phone number']}",
                      "office_phone_number" => "#{phone_numbers['Office phone number']}",
                      "cell_phone_number" => "#{phone_numbers['Cell phone number']}"
                      },
      "patient" => {"identifiers" => {"National id" => "#{national_id}",
                                      "ARV Number" => "#{arv_number}"
                                      }
                   },
      "date_changed" => "#{date_changed}"
    
    }
    results["person"] = result_hash
    return results

  end
 
  def new_encounter(encounter_name,date)
    type = EncounterType.find_by_name(encounter_name)
    encounter = Encounter.new()
    encounter.patient_id = self
    encounter.encounter_datetime = date
    encounter.encounter_type = type
    encounter.save
    encounter
  end

  def self.art_info_for_remote(national_id)

    patient = Patient.find_by_national_id(national_id).first
    results = {}
    result_hash = {}
    
    if patient.art_patient?
    
    first_encounter_date = patient.encounters.find(:first, :order => 'encounter_datetime', 
                             :joins => :type, 
                             :conditions => ['encounter_type NOT IN (?)', 
                                             EncounterType.find_all_by_name(
                                               ['Move file from dormant to active', 'Barcode scan']).map(&:id)]
                                                   ).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

    last_encounter_date = patient.encounters.find(:last, :order => 'encounter_datetime', 
                             :joins => :type, 
                             :conditions => ['encounter_type NOT IN (?)', 
                                             EncounterType.find_all_by_name(
                                               ['Move file from dormant to active', 'Barcode scan']).map(&:id)]
                                                  ).encounter_datetime.strftime("%d-%b-%Y") rescue 'Unknown'

    art_start_date = patient.date_started_art.strftime("%d-%b-%Y") rescue 'Uknown'
    last_given_drugs = patient.drug_orders.last.drug.name rescue 'Uknown'
    art_clinic_outcome = patient.outcome_status rescue 'Uknown'
    date_tested_positive = patient.date_of_positive_hiv_test.strftime("%d-%b-%Y") rescue 'Uknown'
    
   cd4_sql = "SELECT patient_id, cd4_value, cd4_test_date from (SELECT a14.patient_id as 'patient_id', a14.value_numeric as 'cd4_value', a351.value_datetime as 'cd4_test_date' from (select patient_id, concept_id, encounter_id, value_numeric from obs where concept_id = 14) AS a14, (SELECT concept_id, encounter_id, value_datetime from obs where concept_ID = 351) AS a351 where a14.encounter_id = a351.encounter_id) as cd4_data where cd4_data.patient_id = #{patient.id}"
   cd4_info = Observation.find_by_sql(cd4_sql).first rescue nil

   cd4_data_and_date_hash = {}

   if cd4_info
     cd4_data_and_date_hash['date'] = cd4_info.cd4_test_date.to_date.strftime("%d-%b-%Y") 
     cd4_data_and_date_hash['value'] = cd4_info.cd4_value
   end

    result_hash = {
      'art_start_date' => art_start_date,
      'date_tested_positive' => date_tested_positive,
      'first_visit_date' => first_encounter_date,
      'last_visit_date' => last_encounter_date,
      'cd4_data' => cd4_data_and_date_hash,
      'last_given_drugs' => last_given_drugs,
      'art_clinic_outcome' => art_clinic_outcome,
      'arv_number' => patient.arv_number
      }
    end

    results["person"] = result_hash
    return results

   end

   def self.duplicates(attributes)   
    search_str = ''
    ( attributes.sort || [] ).each do | attribute | 
      search_str+= ":#{attribute}" unless search_str.blank?
      search_str = attribute if search_str.blank?
    end rescue []

    return if search_str.blank?
    duplicates = {}
    patients = Patient.find(:all,:conditions =>["voided = 0 AND dead = 0"]) # AND DATE(date_created >= ?) AND DATE(date_created <= ?)",
              #'2005-01-01'.to_date,'2010-12-31'.to_date]) 

    ( patients || [] ).each do | patient |
      if search_str.upcase == "DOB:NAME"
        next if patient.name.blank?
        next if patient.birthdate.blank?
        duplicates["#{patient.name}:#{patient.birthdate}"] = [] if duplicates["#{patient.name}:#{patient.birthdate}"].blank?
        duplicates["#{patient.name}:#{patient.birthdate}"] << patient
      elsif search_str.upcase == "DOB:ADDRESS"
        next if patient.physical_address.blank?
        next if patient.birthdate.blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] = [] if duplicates["#{patient.name}:#{patient.physical_address}"].blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.physical_address.blank?
        next if patient.traditional_authority.blank?
        duplicates["#{patient.traditional_authority}:#{patient.physical_address}"] = [] if duplicates["#{patient.traditional_authority}:#{patient.physical_address}"].blank?
        duplicates["#{patient.traditional_authority}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB"
        next if patient.birthdate.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.birthdate}"].blank?
          duplicates["#{patient.physical_address}:#{patient.birthdate}"] = [] 
        end
        duplicates["#{patient.physical_address}:#{patient.birthdate}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.traditional_authority.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.traditional_authority}"].blank?
          duplicates["#{patient.physical_address}:#{patient.traditional_authority}"] = [] 
        end
        duplicates["#{patient.physical_address}:#{patient.traditional_authority}"] << patient
      elsif search_str.upcase == "ADDRESS:NAME"
        next if patient.name.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.name}"].blank?
          duplicates["#{patient.physical_address}:#{patient.name}"] = [] 
        end
        duplicates["#{patient.physical_address}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.traditional_authority.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.traditional_authority}"].blank?
          duplicates["#{patient.physical_address}:#{patient.traditional_authority}"] = [] 
        end
        duplicates["#{patient.physical_address}:#{patient.traditional_authority}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.traditional_authority.blank?
        next if patient.birthdate.blank?
        if duplicates["#{patient.birthdate}:#{patient.traditional_authority}"].blank?
          duplicates["#{patient.birthdate}:#{patient.traditional_authority}"] = [] 
        end
        duplicates["#{patient.birthdate}:#{patient.traditional_authority}"] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.traditional_authority.blank?
        if duplicates["#{patient.traditional_authority}:#{patient.name}"].blank?
          duplicates["#{patient.traditional_authority}:#{patient.name}"] = []
        end
        duplicates["#{patient.traditional_authority}:#{patient.name}"] << patient  
      elsif search_str.upcase == "ADDRESS:DOB:LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.birthdate.blank?
        next if patient.physical_address.blank?
        next if patient.traditional_authority.blank?
        if duplicates["#{patient.name}:#{patient.birthdate}:#{patient.physical_address}:#{patient.traditional_authority}"].blank?
          duplicates["#{patient.name}:#{patient.birthdate}:#{patient.physical_address}:#{patient.traditional_authority}"] = [] 
        end
        duplicates["#{patient.name}:#{patient.birthdate}:#{patient.physical_address}:#{patient.traditional_authority}"] << patient
      elsif search_str.upcase == "ADDRESS"
        next if patient.physical_address.blank?
        if duplicates[patient.physical_address].blank?
          duplicates[patient.physical_address] = [] 
        end
        duplicates[patient.physical_address] << patient
      elsif search_str.upcase == "DOB"
        next if patient.birthdate.blank?
        if duplicates[patient.birthdate].blank?
          duplicates[patient.birthdate] = [] 
        end
        duplicates[patient.birthdate] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL)"
        next if patient.traditional_authority.blank?
        if duplicates[patient.traditional_authority].blank?
          duplicates[patient.traditional_authority] = [] 
        end
        duplicates[patient.traditional_authority] << patient
      elsif search_str.upcase == "NAME"
        next if patient.name.blank?
        if duplicates[patient.name].blank?
          duplicates[patient.name] = [] 
        end
        duplicates[patient.name] << patient
      end
    end
    hash_to = {}
    duplicates.each do |key,pats |
      next unless pats.length > 1
      hash_to[key] = pats
    end
    hash_to
   end

   def arvs_dispensed?(date = Date.today)
     drug_orders = self.drug_orders(" AND DATE(encounter.encounter_datetime)='#{date.to_date}'")
     (drug_orders || []).each do | drug_order |
      return true if drug_order.drug.arv?
     end 
     return false
   end
  
   def cd4_count_when_starting(date = nil)
     if date.blank? 
       staging_encounter = self.staging_encounter
       return if staging_encounter.blank?
       cd4_obs = self.observations.find(:first,:order => "obs_datetime DESC",
                              :conditions => ["concept_id = ? AND voided = 0 
                              AND DATE(obs_datetime) = ?",
                              Concept.find_by_name("CD4 count").id,
                              staging_encounter.encounter_datetime.to_date])
       else
       cd4_obs = self.observations.find(:first,:order => "obs_datetime DESC",
                              :conditions => ["concept_id = ? AND voided = 0 
                              AND DATE(obs_datetime) = ?",
                              Concept.find_by_name("CD4 count").id,date.to_date])
     end 
     hash = {}
     if not cd4_obs.blank?
       hash[cd4_obs.obs_datetime.to_date] = {:value_modifier => cd4_obs.value_modifier ,
                                             :value_numeric => cd4_obs.value_numeric
                                            }
       return hash
     end  

     show_cd4_trail = GlobalProperty.find_by_property("show_lab_trail").property_value rescue "false"

     return if not show_cd4_trail == "true"
     date = date.to_date rescue staging_encounter.encounter_datetime.to_date
     cd4_count_from_healthdata_when_starting(self,date)
   end

   def taken_arvs_before?
     self.drug_orders.each do | d |
       return true if d.drug.arv?
     end
     return false
   end



   private                                                                      
                                                                                
   def cd4_count_from_healthdata_when_starting(patient , start_date)                                          
     test_types = LabTestType.find(:all,:conditions=>["(TestName=? or TestName=?)",
                  "CD4_count","CD4_percent"]).map{|type|type.TestType} rescue []

     cd4_hash = {}
     available_cd4_tests = patient.detail_lab_results("CD4") rescue {}
     cd4_counts = available_cd4_tests.sort{|a,b| b[0].to_date<=>a[0].to_date}
     cd4_counts.each do |date , results|
       next unless start_date == date.to_date
       results.each do | r |
         r.each do |result|
           case result.TESTTYPE
             when test_types.first
               value_modifier = result.Range || "="
               cd4_count = result.TESTVALUE
               cd4_hash[date.to_date] = {:value_modifier => value_modifier ,
                                 :value_numeric => cd4_count} unless cd4_count.blank?
               return cd4_hash unless cd4_hash.blank?
           end rescue []
         end
       end
     end unless available_cd4_tests.blank?
     cd4_hash
   end 

end

### Original SQL Definition for patient #### 
#   `patient_id` int(11) NOT NULL auto_increment,
#   `gender` varchar(50) NOT NULL default '',
#   `race` varchar(50) default NULL,
#   `birthdate` date default NULL,
#   `birthdate_estimated` tinyint(1) default NULL,
#   `birthplace` varchar(50) default NULL,
#   `tribe` int(11) default NULL,
#   `citizenship` varchar(50) default NULL,
#   `mothers_name` varchar(50) default NULL,
#   `civil_status` int(11) default NULL,
#   `dead` int(1) NOT NULL default '0',
#   `death_date` datetime default NULL,
#   `cause_of_death` varchar(255) default NULL,
#   `health_district` varchar(255) default NULL,
#   `health_center` int(11) default NULL,
#   `creator` int(11) NOT NULL default '0',
#   `date_created` datetime NOT NULL default '0000-00-00 00:00:00',
#   `changed_by` int(11) default NULL,
#   `date_changed` datetime default NULL,
#   `voided` tinyint(1) NOT NULL default '0',
#   `voided_by` int(11) default NULL,
#   `date_voided` datetime default NULL,
#   `void_reason` varchar(255) default NULL,
#   PRIMARY KEY  (`patient_id`),
#   KEY `belongs_to_tribe` (`tribe`),
#   KEY `user_who_created_patient` (`creator`),
#   KEY `user_who_voided_patient` (`voided_by`),
#   KEY `user_who_changed_pat` (`changed_by`),
#   KEY `birthdate` (`birthdate`),
#   CONSTRAINT `belongs_to_tribe` FOREIGN KEY (`tribe`) REFERENCES `tribe` (`tribe_id`),
#   CONSTRAINT `user_who_changed_pat` FOREIGN KEY (`changed_by`) REFERENCES `users` (`user_id`),
#   CONSTRAINT `user_who_created_patient` FOREIGN KEY (`creator`) REFERENCES `users` (`user_id`),
#   CONSTRAINT `user_who_voided_patient` FOREIGN KEY (`voided_by`) REFERENCES `users` (`user_id`)
