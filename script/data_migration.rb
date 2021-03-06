
def migrate_patients
  table = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['migration']
  TableMain.establish_connection(table)
  TableHivRelatedIllness.establish_connection(table)
  TableList.establish_connection(table)
  TableOtherFu.establish_connection(table)
  TableOutcome.establish_connection(table)


  TableSideEffect.establish_connection(table)
  TableTb.establish_connection(table)
  TableHospitalization.establish_connection(table)
  TableLabResult.establish_connection(table)
  TableLabResultList.establish_connection(table)
  DataCleanUp.establish_connection(table)

=begin

  TableMain.create_patients
  puts ""
  puts ""
  puts ""
  puts ""
  puts ""
  puts ""
  puts ""
  puts "Creating TB visit encounters"
  TableMain.tb_visits
  puts ""
  puts ""
  puts ""
  puts ""
  puts ""
  puts ""
  puts ""
  #puts "Creating hospital visit encounters"
 # TableMain.hospital_visit
#  puts "Creating Lab results"
  TableMain.lab_results
=end
  DataCleanUp.migrate_data
end

User.current_user = User.find(1)
migrate_patients





