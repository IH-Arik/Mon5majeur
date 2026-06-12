import CardUser from '@/components/modules/dashboard/CardUser'
import UserManagement from '@/components/modules/dashboard/UserManagement'
import React from 'react'

export default function page() {
  return (
    <div>
      <h2 className='text-[24px] md:text-[28px] lg:text-[30px] font-semibold'>User Management</h2>
      <p className='text-[14px] md:text-[16px]'>Oversee user accounts, control access within the platform.</p>
       <CardUser></CardUser>
      <UserManagement></UserManagement>
    </div>
  )
}
