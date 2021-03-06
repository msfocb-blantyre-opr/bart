class AddEdsToPatientNationalId < ActiveRecord::Migration
  def self.up
    PatientNationalId.reset_column_information
    add_column :patient_national_id, :eds, :boolean, :default => 0 unless PatientNationalId.column_names.include?('eds') 
  end

  def self.down
    PatientNationalId.reset_column_information
    remove_column :patient_national_id, :default, :eds if PatientNationalId.column_names.include?('default')
    #remove_column :patient_national_id, :eds
  end
end
