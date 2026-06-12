import LeagueCard from '@/components/modules/dashboard/LeagueCard'
import LeagueManagement from '@/components/modules/dashboard/LeagueManagement'
import React from 'react'

export default function page() {
  return (
    <div>
      <h2 className='text-[24px] md:text-[28px] lg:text-[30px] font-semibold'>League Management</h2>
      <p className='text-[14px] md:text-[16px]'>Oversee user accounts, control access within the platform.</p>
      <LeagueCard></LeagueCard>
      <LeagueManagement></LeagueManagement>
    </div>
  )
}
