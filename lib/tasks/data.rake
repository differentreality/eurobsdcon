# frozen_string_literal: true

namespace :data do
  desc 'Nullify wrong foreign keys'

  task nullify_nonexistent_foreign_keys: :environment do
    # Track
    events_track = Event.all.select { |e| e.track_id && Track.find_by(id: e.track_id).nil? }
    nullify_attribute(events_track, 'track_id')

    # Difficulty level
    events_difficulty_level = Event.all.select { |e| e.difficulty_level_id && DifficultyLevel.find_by(id: e.difficulty_level_id).nil? }
    nullify_attribute(events_difficulty_level, 'difficulty_level_id')

    # Room
    events_room = Event.all.select { |e| e.room_id && Room.find_by(id: e.room_id).nil? }
    nullify_attribute(events_room, 'room_id')
  end

  desc 'Drop all ahoy events'
  task drop_all_ahoy_events: :environment do
    class TmpAhoy < ActiveRecord::Base
      self.table_name = 'ahoy_events'
    end
    TmpAhoy.delete_all
  end

  def nullify_attribute(collection, attribute)
    puts "Will nullify #{attribute} in #{ActionController::Base.helpers.pluralize(collection.length, 'event')}."
    if collection.any?
      puts "IDs: #{collection.map(&:id)}"
      collection.each do |item|
        item.send(attribute+'=', nil)
        item.save!
      end
      puts "Fixed #{attribute}!"
    end
  end

  ##
  # Add survey for registration
  # For specific conference (by short_title)
  task :add_survey, [:conference_short_title, :duplicate] => :environment do |t, args|

    conference = Conference.find_by(short_title: args.conference_short_title)
    fail 'To continue, you need to provide the short_title of a conference. Usage: rake data:add_survey[short_title]' unless args.conference_short_title && conference
    # Do not create dplicate survey, unless duplicate
    if conference.surveys.for_registration.any? && !args.duplicate
      fail 'You already have a survey during registration. If you want to create another one, pass the argument true after the conference short_title. Usage: rake data:add_survey[short_title,true]'
    end

    registration_survey = create(:survey, surveyable: conference, target: :during_registration, title: 'Survey during registation', start_date: conference.registration_period.start_date, end_date: conference.registration_period.end_date, description: 'Survey during registration.')

    tshirt_size_question = create(:choice_non_mandatory_1_reply, survey: registration_survey, title: "What's your T-shirt size?", possible_answers: 'S, M, L, XL')

    puts 'Successfully created a survey to show during registration.'
  end
end
