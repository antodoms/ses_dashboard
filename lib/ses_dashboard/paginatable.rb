module SesDashboard
  # Lightweight pagination that avoids requiring kaminari or will_paginate.
  # Returns [records, pagination_info] where pagination_info is a Hash.
  #
  # Usage:
  #   records, pagination = Paginatable.paginate(scope, page: 2, per_page: 25)
  #
  module Paginatable
    def self.paginate(scope, page:, per_page: nil)
      per_page    = (per_page || SesDashboard.configuration.per_page).to_i
      page        = [page.to_i, 1].max
      total_count = scope.count
      total_pages = [(total_count.to_f / per_page).ceil, 1].max
      page        = [page, total_pages].min

      records = scope.offset((page - 1) * per_page).limit(per_page)

      pagination = {
        page:        page,
        per_page:    per_page,
        total_count: total_count,
        total_pages: total_pages,
        prev_page:   page > 1 ? page - 1 : nil,
        next_page:   page < total_pages ? page + 1 : nil
      }

      [records, pagination]
    end
  end
end
