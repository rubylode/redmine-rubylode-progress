# Rubylode Progress: a progress page for Redmine projects
# Copyright (C) 2026  Nick Gorbikoff
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
require_relative "../rubylode_progress/demo_data"

namespace :redmine_rubylode_progress do
  desc "Build the demo projects, versions and issues (does nothing when they are already there)"
  task demo: :environment do
    result = RubylodeProgress::DemoData.build
    if result == :built
      puts "Demo built: #{Project.count} projects, #{Issue.count} issues. Sign in as " \
           "#{RubylodeProgress::DemoData::DEMO_LOGIN} / #{RubylodeProgress::DemoData::DEMO_PASSWORD}."
    else
      puts "Demo data already loaded: #{Project.count} projects, #{Issue.count} issues."
    end
  end
end
