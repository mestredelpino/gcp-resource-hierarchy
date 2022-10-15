terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.38.0"
    }
  }
}

provider "google" {
  project = var.org_domain
}


locals {
  departments = flatten([
    for department, department_info in var.resource_hierarchy : {
      folder        = department_info.department
      parent_folder = data.google_organization.org.id
    }
  ])

  teams = flatten([
    for department, department_info in var.resource_hierarchy : [
      try(flatten([for team, team_info in department_info.teams : {
        folder          = team_info.name
        parent_folder = department_info.department
      }]),null)
    ]
  ])

  products = flatten([
    for department, department_info in var.resource_hierarchy : [
      try(flatten([for team, team_info in department_info.teams : [
        try(flatten([for product, product_info in team_info.products: {
          folder        = product_info.name
          parent_folder = team_info.name
        }]),null)
      ]]),null)
    ]
  ])

  projects = flatten([
    for department, department_info in var.resource_hierarchy : [
      try([for project, project_info in department_info.projects : {
        parent_folder = department_info.department
        project       = department_info.projects[project]
      }],null),
      try([for team, team_info in department_info.teams : [
        try([for project, project_info in team_info.projects : {
          parent_folder = team_info.name
          project       = team_info.projects[project]
        }],null),
        try([for product, product_info in team_info.products: [
          try([for project, environment in product_info.projects :{
            parent_folder = product_info.name
            project       = product_info.projects[project]#replace(lower("${product_info.name}-${environment}74820846")," ","-")
          }],null)
        ]],null)
      ]],null)
    ]
  ])
}

data "google_organization" "org" {
  domain = var.org_domain
}

resource "google_folder" "department" {
  for_each =  { for index, department in local.departments: department.folder => department }
  display_name = each.value.folder
  parent       = data.google_organization.org.id
}

resource "google_folder" "teams" {
  for_each =  { for index, team in local.teams: team.folder => team if can(team.folder)}
  display_name = each.value.folder
  parent       = google_folder.department[each.value.parent_folder].id
}

resource "google_folder" "product" {
  for_each =  { for index, product in local.products: product.folder => product if can(product.folder)}
  display_name = each.value.folder
  parent       = google_folder.teams[each.value.parent_folder].id
}

resource "google_project" "project" {
  for_each =  { for index, project in local.projects: project.project => project if can(project.project)}
  name       = each.value.project
  project_id = each.value.project
  folder_id  = try(try(google_folder.department[each.value.parent_folder].id,google_folder.teams[each.value.parent_folder].id),google_folder.product[each.value.parent_folder].id)
}